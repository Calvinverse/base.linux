# frozen_string_literal: true

#
# Cookbook Name:: base_linux
# Recipe:: system_logs
#
# Copyright 2017, P. van der Velde
#

#
# INSTALL SYSLOG-NG
#

apt_repository 'syslog-ng-apt-repository' do
  action :add
  distribution './'
  key 'http://download.opensuse.org/repositories/home:/laszlo_budai:/syslog-ng/xUbuntu_16.04/Release.key'
  uri 'http://download.opensuse.org/repositories/home:/laszlo_budai:/syslog-ng/xUbuntu_16.04'
end

# Installing the syslog-ng package automatically creates a systemd daemon and replaces the other
# syslog daemons
%w[syslog-ng-core syslog-ng-mod-amqp syslog-ng-mod-json].each do |pkg|
  apt_package pkg do
    action :install
    version '3.16.1-1'
  end
end

syslog_ng_config_path = node['syslog_ng']['config_path']
directory syslog_ng_config_path do
  action :create
end

#
# CONSUL TEMPLATE FILES
#

consul_template_template_path = node['consul_template']['template_path']
consul_template_config_path = node['consul_template']['config_path']

# Create the consul-template template file
syslog_ng_template_file = node['syslog_ng']['consul_template_file']
file "#{consul_template_template_path}/#{syslog_ng_template_file}" do
  action :create
  content <<~CONF
    @version: 3.16

    ########################
    # Destinations
    ########################
    # The RabbitMQ destination
    destination d_rabbit {
      amqp(
        body("$(format-json date=datetime($ISODATE) pid=$PID program=$PROGRAM message=$MESSAGE facility=$FACILITY host=$FULLHOST priorityNum=int64($LEVEL_NUM) priority=$LEVEL)")
        exchange("{{ keyOrDefault "config/services/queue/logs/syslog/exchange" "" }}")
        exchange-type("direct")
        host("{{ keyOrDefault "config/services/queue/protocols/amqp/host" "unknown" }}.service.{{ keyOrDefault "config/services/consul/domain" "consul" }}")
        port({{ keyOrDefault "config/services/queue/protocols/amqp/port" "80" }})
        routing-key("syslog")
        vhost("{{ keyOrDefault "config/services/queue/logs/syslog/vhost" "logs" }}")

    {{ with secret "rabbitmq/creds/write.vhost.logs.syslog" }}
      {{ if .Data.password }}
        password("{{ .Data.password }}")
        username("{{ .Data.username }}")
      {{ end }}
    {{ end }}
      );
    };

    ########################
    # Log paths
    ########################

    log { source(s_src); filter(f_syslog3); destination(d_rabbit); };
  CONF
  group 'root'
  mode '0550'
  owner 'root'
end

# Create the consul-template configuration file
syslog_ng_config_file = node['syslog_ng']['config_file']
file "#{consul_template_config_path}/syslog-ng.hcl" do
  action :create
  content <<~HCL
    # This block defines the configuration for a template. Unlike other blocks,
    # this block may be specified multiple times to configure multiple templates.
    # It is also possible to configure templates via the CLI directly.
    template {
      # This is the source file on disk to use as the input template. This is often
      # called the "Consul Template template". This option is required if not using
      # the `contents` option.
      source = "#{consul_template_template_path}/#{syslog_ng_template_file}"

      # This is the destination path on disk where the source template will render.
      # If the parent directories do not exist, Consul Template will attempt to
      # create them, unless create_dest_dirs is false.
      destination = "#{syslog_ng_config_path}/#{syslog_ng_config_file}"

      # This options tells Consul Template to create the parent directories of the
      # destination path if they do not exist. The default value is true.
      create_dest_dirs = false

      # This is the optional command to run when the template is rendered. The
      # command will only run if the resulting template changes. The command must
      # return within 30s (configurable), and it must have a successful exit code.
      # Consul Template is not a replacement for a process monitor or init system.
      command = "systemctl restart syslog-ng"

      # This is the maximum amount of time to wait for the optional command to
      # return. Default is 30s.
      command_timeout = "15s"

      # Exit with an error when accessing a struct or map field/key that does not
      # exist. The default behavior will print "<no value>" when accessing a field
      # that does not exist. It is highly recommended you set this to "true" when
      # retrieving secrets from Vault.
      error_on_missing_key = false

      # This is the permission to render the file. If this option is left
      # unspecified, Consul Template will attempt to match the permissions of the
      # file that already exists at the destination path. If no file exists at that
      # path, the permissions are 0644.
      perms = 0550

      # This option backs up the previously rendered template at the destination
      # path before writing a new one. It keeps exactly one backup. This option is
      # useful for preventing accidental changes to the data without having a
      # rollback strategy.
      backup = true

      # These are the delimiters to use in the template. The default is "{{" and
      # "}}", but for some templates, it may be easier to use a different delimiter
      # that does not conflict with the output file itself.
      left_delimiter  = "{{"
      right_delimiter = "}}"

      # This is the `minimum(:maximum)` to wait before rendering a new template to
      # disk and triggering a command, separated by a colon (`:`). If the optional
      # maximum value is omitted, it is assumed to be 4x the required minimum value.
      # This is a numeric time with a unit suffix ("5s"). There is no default value.
      # The wait value for a template takes precedence over any globally-configured
      # wait.
      wait {
        min = "2s"
        max = "10s"
      }
    }
  HCL
  group 'root'
  mode '0550'
  owner 'root'
end
