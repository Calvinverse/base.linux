# frozen_string_literal: true

#
# Cookbook Name:: base_linux
# Recipe:: default
#
# Copyright 2017, P. van der Velde
#

# Always make sure that apt is up to date
apt_update 'update' do
  action :update
end

#
# Include the local recipes
#

include_recipe 'base_linux::firewall'

include_recipe 'base_linux::consul'
include_recipe 'base_linux::consul_template'
include_recipe 'base_linux::network'
include_recipe 'base_linux::provisioning'