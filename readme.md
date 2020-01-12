# Local Kubernetes cluster
This repo contains configuration files that are necessary to start a local kubernetes cluster using [Vagrant](https://vagrantup.com).

Make sure you have both *vagrant* and *virtualbox* installed and run:

```bash
vagrant up
```

The nodes are named cp and worker. To SSH to the master node just do:

```bash
vagrant ssh k8s-node-1
```

> Remember to become *root* by ```sudo su``` so you can properly run the kubectl commands.
