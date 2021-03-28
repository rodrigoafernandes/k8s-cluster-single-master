vms = {
    'cp' => {'memory' => '2048', 'cpus' => '2', 'ip' => '10', 'role' => 'master'},
    'node1' => {'memory' => '1024', 'cpus' => '1', 'ip' => '20', 'role' => 'worker'},
    'node2' => {'memory' => '1024', 'cpus' => '1', 'ip' => '30', 'role' => 'worker'}
}

Vagrant.configure("2") do |config|
    config.vm.box = "ubuntu/focal64"
    config.vm.synced_folder "./shared", "/opt/vagrant/data"
    defaul_host = "-k8s.gigiodesenvolvimento.com.br"

    vms.each do |name, conf|
        ip_private = "192.168.20.#{conf['ip']}"

        config.vm.define "#{name}" do |k|
            k.vm.hostname = "#{name}" + defaul_host
            k.vm.network "private_network", ip: ip_private

            k.vm.provider "virtualbox" do |vbox|
                vbox.name = name
                vbox.memory = conf['memory']
                vbox.cpus = conf['cpus']
            end

            k.vm.provision "shell" do |shell|
                shell.path = "./shared/config-cluster.sh"
                shell.args = [ip_private, conf['role']]
            end
            k.trigger.after :up do |trigger|
                if "#{name}" == 'node'
                    trigger.only_on = 'cp'
                    trigger.run_remote = {path: "./shared/config-resources.sh"}
                end
            end
        end
    end
end