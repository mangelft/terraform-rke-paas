provider "opennebula" {
  endpoint = "${var.endpoint_url}"
  username = "${var.one_username}"
  password = "${var.one_password}"
}

data "template_file" "k8s-template" {
  template = "${file("k8s-template.tpl")}"
}

resource "opennebula_template" "k8s-template" {
  name = "k8s-template"
  description = "${data.template_file.k8s-template.rendered}"
  permissions = "600"
}

resource "opennebula_vm" "k8s-node" {
  name = "k8s-node${count.index}"
  template_id = "${opennebula_template.k8s-template.id}"
  cpu = "1"
  memory = "2"
  vcpu = "1"
  permissions = "600"

  # This will create 1 instances
  count = 1

  connection {
    host = "${self.ip}"
    type = "ssh"
    user = "ubuntu"
    private_key = "${file("~/.ssh/id_rsa")}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum update -y",
      "sudo curl https://releases.rancher.com/install-docker/17.03.sh | sh ",
      "sudo usermod -aG docker $USER ",
    ]
  }
}

resource "rke_cluster" "cluster" {
  nodes = [
    {
      address = "${element(opennebula_vm.k8s-node.*.ip, count.index)}"
      user    = "ubuntu"
      role    = ["controlplane", "worker", "etcd"]
    },
  ]
  cluster_name = "one.cluster.local"

  network {
    plugin = "flannel"
  }
}

resource "local_file" "kube_cluster_yaml" {
  filename = "${path.root}/kube_config_cluster.yml"
  content = "${rke_cluster.cluster.kube_config_yaml}"
}

