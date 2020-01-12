vms = {
    'cp' => {'memory' => '2048', 'cpus' => '2', 'ip' => '10', 'role' => 'master'},
    'node1' => {'memory' => '4096', 'cpus' => '2', 'ip' => '20', 'role' => 'worker'},
    'node2' => {'memory' => '4096', 'cpus' => '2', 'ip' => '30', 'role' => 'worker'},
    'pcr' => {'memory' => '1024', 'cpus' => '1', 'ip' => '40', 'role' => 'registry'}
}

Vagrant.configure("2") do |config|
    config.vm.box = "ubuntu/bionic64"
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
                shell.path = "./shared/bootstrap.sh"
                shell.args = [ip_private, conf['role']]
            end
        end
    end
end