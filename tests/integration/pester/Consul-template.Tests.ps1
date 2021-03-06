BeforeAll {
    $expectedContent = @'
[Service]
ExecStart = /usr/local/bin/run_consul-template.sh
RestartSec = 5
Restart = always
EnvironmentFile = /etc/environment

[Unit]
Description = Consul Template
Documentation = https://github.com/hashicorp/consul-template
Requires = multi-user.target
After = multi-user.target
StartLimitIntervalSec = 0

[Install]
WantedBy = multi-user.target

'@

    $serviceConfigurationPath = '/etc/systemd/system/consul-template.service'
    $serviceFileContent = Get-Content $serviceConfigurationPath | Out-String
    $systemctlOutput = & systemctl status consul-template
}

Describe 'The consul-template application' {
    Context 'is installed' {
        It 'with binaries in /usr/local/bin' {
            '/usr/local/bin/consul-template' | Should -Exist
            '/usr/local/bin/run_consul-template.sh' | Should -Exist
        }

        It 'with default configuration in /etc/consul-template.d/config/base.hcl' {
            '/etc/consul-template.d/conf/base.hcl' | Should -Exist
        }

        It 'with a data directory in /etc/consul-template.d/data' {
            '/etc/consul-template.d/data' | Should -Exist
        }
    }

    Context 'has been daemonized' {
        It 'has a systemd configuration' {
            $serviceConfigurationPath | Should -Exist
        }

        It 'with a systemd service' {
            $serviceFileContent | Should -Be ($expectedContent -replace "`r", "")

            $systemctlOutput | Should -Not -Be $null
            $systemctlOutput.GetType().FullName | Should -Be 'System.Object[]'
            $systemctlOutput.Length | Should -BeGreaterThan 3
            $systemctlOutput[0] | Should -Match 'consul-template.service - Consul Template'
        }

        It 'that is enabled' {
            $systemctlOutput[1] | Should -Match 'Loaded:\sloaded\s\(.*;\senabled;.*\)'

        }

        It 'and is running' {
            $systemctlOutput[2] | Should -Match 'Active:\sactive\s\(running\).*'
        }
    }
}
