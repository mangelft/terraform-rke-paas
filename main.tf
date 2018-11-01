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

  # This will create 2 instances
  count = "${var.master_nodes}"

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

data rke_node_parameter "nodes" {
  count = "${var.master_nodes}"

  address = "${element(opennebula_vm.k8s-node.*.ip, count.index)}"
  user    = "ubuntu"
  role    = ["controlplane", "worker", "etcd"]
  ssh_key = "${file("~/.ssh/id_rsa")}"
}

resource "rke_cluster" "cluster" {
  nodes_conf = ["${data.rke_node_parameter.nodes.*.json}"]
  
  cluster_name = "one.cluster.local"

  network {
    plugin = "flannel"
  }

  addons = <<EOL
---
kind: Namespace
apiVersion: v1
metadata:
  name: cattle-system
---
kind: ServiceAccount
apiVersion: v1
metadata:
  name: cattle-admin
  namespace: cattle-system
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: cattle-crb
  namespace: cattle-system
subjects:
- kind: ServiceAccount
  name: cattle-admin
  namespace: cattle-system
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: Secret
metadata:
  name: cattle-keys-ingress
  namespace: cattle-system
type: Opaque
data:
  tls.crt: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUVSRENDQWl3Q0NRQ2VkV0tCUzZicXFUQU5CZ2txaGtpRzl3MEJBUXNGQURCbk1Rc3dDUVlEVlFRR0V3SkYKVXpFVE1CRUdBMVVFQ0F3S1UyOXRaUzFUZEdGMFpURVNNQkFHQTFVRUJ3d0pRbUZ5WTJWc2IyNWhNUk13RVFZRApWUVFLREFwU1lXNWphR1Z5SUVOQk1Sb3dHQVlEVlFRRERCRmpZUzV5WVc1amFHVnlMbTE1TG05eVp6QWVGdzB4Ck9ERXdNamd4T0RJeU16ZGFGdzB5TURBek1URXhPREl5TXpkYU1HRXhDekFKQmdOVkJBWVRBa1ZUTVJNd0VRWUQKVlFRSURBcFRiMjFsTFZOMFlYUmxNUkl3RUFZRFZRUUhEQWxDWVhKalpXeHZibUV4RURBT0JnTlZCQW9NQjFKaApibU5vWlhJeEZ6QVZCZ05WQkFNTURuSmhibU5vWlhJdWJYa3ViM0puTUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGCkFBT0NBUThBTUlJQkNnS0NBUUVBdkRoUG8zbzU2V0VnWTcwaTYrU3g3YXR1SGkyQkZidmVwbDJ2dzZCN3N6c0oKM295d3o0L25HbG0vc2YxYlBTTzhkRTBMcDZReUNzM1YzbTUzMlBPU3hnQkpRYU1pRlU0OFdGRC9aS2JJeDNsTQpZNGNRT1lRL21BTFJnVmhmNC84anArY3p2VjRITFVNT29Fb3htWGxSM0ZrZmZOZ0FBbThleTdpM0hxakl6ZFgrCi8wVWorb0pmbDVIdjVnMXAvbUhzRlRaZm90Qks4SEt3eE1yN2U0TjA2dncxU2VTTWpEQmFzVWpZcyt3QlI2cHAKUWZ2MWxDYlBUemNHWDZ5b2NPZTVtb2Q3UFRlMHg5N2dJRzY0QnVYS1IyUS9yUUwxak9qL2tNZXNndEVXQnlTNwpaOUNVSm0rZzl1dVpSTHIyUkkvSkZFc2NiNU15SGc5OWtQU2I2dnJCbVFJREFRQUJNQTBHQ1NxR1NJYjNEUUVCCkN3VUFBNElDQVFDbStCaEtlSVhrOTNzOElHRGpqbnNIZWR1WVRyRTNHZnRnTU5SWWJZOWcrS01lRUF6Tjk5NkwKYklnOHZkVkFLS3Zsa1BmbC9TajhkRFplTmg5ZzlXcDNSY3I5WHZGWXRud0hPNG1Bb2tCaDNaMjhsWHVJZ2pmSQo0QnJRZ1F6Z3liQldkNFY3VFdvblVXREhhSFBJa2MybU56TGw3MEU1ODRjcXpNdU5FK2hQS0pLSkdQcnRSMEpvCk96c2sydWFWbVk0bXBybStwanQxeHhoektzeEJvNlhmNGd5a1lhcUhoaytsaGdrMjdScFE2bmh6U0UwQ0hVbzAKZW1rTjlUTG9sS3kxUEx3TTJGNXhLRXVRdTN0S1c1V2JvWmtKTVNSenFxWkgxMmhkWWl5NzhGMmxwUERuRkoxNQpxSjR3YzVSaTVqb25OSzMzdVZ3NHY0RVdWbzlyVVErdXVBYmlIN1Ztc2VvQnJqeDlTQ1lKT1dDc3dNekhVNXZBCmFjVElpMHZiRy9sYmxsWjYrVXErVVp2ZkQ5WDFmKy9jRmVJVVlSTktyOWdKcnp4YzZUUldTYTlzZU0zL0dwMHQKeFYrQzE2QUEwbE83SmMvK3ErZ0tpWis1K3VQNjc1QUFsc3YwZFRha3ZKNno3UFFzM1FSeTAxblg2cjlRVXoyOQplZUw5RnBoUzZENFl3cFdhMGVnRTdLamlBSDRTbUJyTm11RjBpZ216Vi9MUE9ndlVidHlxdDFsU0pQYkc0aXFICmpqVGdveFZ3dFZhS3JFWTZLblBnTExGdW5WaFNidGlsNUNpcGV6eHZkYzRRejFUL0ZSSlJ2YW5POXBZemdiQzUKT2JQQ083cVdXZUdBNTd1dGJUNFZUNk4xdzFjS0tsVEk1SU9tQVJjMEoxMVZrZm1SdmpoWnRnPT0KLS0tLS1FTkQgQ0VSVElGSUNBVEUtLS0tLQo=
  tls.key: LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb2dJQkFBS0NBUUVBdkRoUG8zbzU2V0VnWTcwaTYrU3g3YXR1SGkyQkZidmVwbDJ2dzZCN3N6c0ozb3l3Cno0L25HbG0vc2YxYlBTTzhkRTBMcDZReUNzM1YzbTUzMlBPU3hnQkpRYU1pRlU0OFdGRC9aS2JJeDNsTVk0Y1EKT1lRL21BTFJnVmhmNC84anArY3p2VjRITFVNT29Fb3htWGxSM0ZrZmZOZ0FBbThleTdpM0hxakl6ZFgrLzBVagorb0pmbDVIdjVnMXAvbUhzRlRaZm90Qks4SEt3eE1yN2U0TjA2dncxU2VTTWpEQmFzVWpZcyt3QlI2cHBRZnYxCmxDYlBUemNHWDZ5b2NPZTVtb2Q3UFRlMHg5N2dJRzY0QnVYS1IyUS9yUUwxak9qL2tNZXNndEVXQnlTN1o5Q1UKSm0rZzl1dVpSTHIyUkkvSkZFc2NiNU15SGc5OWtQU2I2dnJCbVFJREFRQUJBb0lCQUhJLzZDOStVTXJXRnhnVAp4YS9VMlNCQWNBNUhadFN2Zmo0VUhrMnNDNHBHNnYyNC90WnZMa1B6ZUlYdEdVWHFmRWxJUHl2YVlqbm1xY3hqCjE4SE1VQ3A2SC8yRXJYcXJTN3Y4SnBxTkZ0RG1VelVTMWdsanVrcG1ZNCtVK2xmbUZsbWo0T2N3dlVCL05OQ2QKV0xBbFVVaGtuTlZtTTlOR2FqWVZBS3JPbjEwNVhycUUyY09ZdGtQWUppMzBMaFB1ZVB6NmVxTkh3bm9VNXREVgpnYW9OczBoQWRER2N1aVpxbFhOMzl1UUNON1lZVko1VFB6NE9QY3dkVTg1byswRmJJdUFBa1VHUElMMHQ4SElSCnhFcU0wTEthS2dFZFZhUkJGbzZhZWRmaXpaMEZJclpyWEtnNDYrTDRtU0lWUmNJVlZnekp1ZUd1MDhYcytJMXMKakVEd2FRVUNnWUVBNTRzMi9JanowS0IxSDM0WDZ1Y3l5eml2c1pHZmNKUmhwMjNxWFUzMmoybllueUZBU2JGTQo4dnQ0V3VYL0ZaQ0pVWkRPZDJ0MDJZZ3NjNGE3V0FLTWFUZVpZRkNoc1gzeEQ2cW0rRGkzNkczaEVtZGc1MkYyCm8yZWw5R21TL2FHeXB6TjVhYW1SNERPL2M2ZTJwT1Z4ay9nUVBiV29OUFRGMlNGb2RER3pLRzhDZ1lFQTBCbW0KUDcxNkIreStJNGVDTTk1UCtXeGxSVXZ5eVdXNjFsS1I5cGdzWkQ4bHU2bXh2cGM4aFdWR1diUHlHLzgwSDVWNwpPR2ZRczc1SU91ZTlGT0NVWGdjN1Mwd0g2SHBGd3JiZ3NrSFd4NTN4UGJ6cnR1KzBLVlpSMkduODJnaVgzL0M3ClFLM2FtdjZrek9tQ2h0T2xodFNiZFdSSG03aDNnTTdJSnlYYmFuY0NnWUFraWQyRmdIOHBQd2o4alVOcytFc1YKc3I1WEFTbnQ5QnhzOVhWMGYrY1d2cGRHbFZLMXpscmNSVDY2Nld5VmxKZDIzYWtYUTBmUFJDUHZueVZWUUNHMApRT2ZkUVJ3akRFTE1QQnZaTStvaHJhVkU2RGRzaS83U3pucHIxWFV5dlIrYUx3OUwwMHlIMnVLdGQ1dms3YWc4CnQzcW9vbEFHKzFGMWNFWXhmOTVMMVFLQmdBb3doMVJ0cWJFRHBaZkZ4ZGxXVkdJcExaaEVETUpSeWVFK3I4ajgKVUlna0UydnA5anNYMnEzSmRMVmx1MEFsc2Q2dUNoZUw5Y3NuVVJBWlVzZlg2MHZqWE1MbUdTa0grNng2R2V5QQpqc3k5YmhlUXpaWHFqTTdOWERxVmpmejdHTHl0WSszWjFXOXJjcFJhQnJzbFYrQ1BQb0YwQkpHYWFiZVQ2SGNLClFvRW5Bb0dBRUlUemNldFQvWGdkcGVxVGtSTnc5a0Vob1ROZi9DdDlKaEZ6YUh0TVZ1dWRpdnJLMzYvbGNDUlcKWjc1N1VoaHJ1eHhWOVJzeEVGVGVsZ2RiM1VncmR4Vk1Zb0VnTGsxODI3aVhwYUlQYVBNRHFRWldBOVRkWGJtcQpTaFEreVBUSkhFMnlJbnpVRHEyZ3loWDFMa0xPK2VnYkM0dytXd2RsRmdvWG8vM1FiUE09Ci0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tCg==
---
apiVersion: v1
kind: Secret
metadata:
  name: cattle-keys-server
  namespace: cattle-system
type: Opaque
data:
  cacerts.pem: LS0tLS1CRUdJTiBDRVJUSUZJQ0FURS0tLS0tCk1JSUZvVENDQTRtZ0F3SUJBZ0lKQU1OeHFiU0hZS3diTUEwR0NTcUdTSWIzRFFFQkN3VUFNR2N4Q3pBSkJnTlYKQkFZVEFrVlRNUk13RVFZRFZRUUlEQXBUYjIxbExWTjBZWFJsTVJJd0VBWURWUVFIREFsQ1lYSmpaV3h2Ym1FeApFekFSQmdOVkJBb01DbEpoYm1Ob1pYSWdRMEV4R2pBWUJnTlZCQU1NRVdOaExuSmhibU5vWlhJdWJYa3ViM0puCk1CNFhEVEU0TVRBeU9ERTRNVGswTmxvWERUSXhNRGd4TnpFNE1UazBObG93WnpFTE1Ba0dBMVVFQmhNQ1JWTXgKRXpBUkJnTlZCQWdNQ2xOdmJXVXRVM1JoZEdVeEVqQVFCZ05WQkFjTUNVSmhjbU5sYkc5dVlURVRNQkVHQTFVRQpDZ3dLVW1GdVkyaGxjaUJEUVRFYU1CZ0dBMVVFQXd3UlkyRXVjbUZ1WTJobGNpNXRlUzV2Y21jd2dnSWlNQTBHCkNTcUdTSWIzRFFFQkFRVUFBNElDRHdBd2dnSUtBb0lDQVFEbDhjMElaYzZlTWFoanFUS2JTZFArODBQUUwvbFUKQkZWWnhYaGNjZXhCTWlHd3dYdnJpby9VZWxDenpxU3FjSkE3MHBKT2E4Njc3cklvZC8xRFZCQ2xHcWxGSWtkUQpTSmJpdmx5NU5oT29xVlFib2Z4d0c4L1hhYnU5aU1sTFhaTjRyQS9iSnNDRk16K0dORUdSSktTU1FyZUcvV0diClVCc2taRktDV29STUJXYm9XanRIMlpab29EbVJleFAzUFpKaFViTFdKd1UwNkQwTW5OQWRNSkNaOVA1ZUc2TUIKcGF0QytFSXFIdjBJUGl5Qm9zdzAvUmhQK3RPMHhYQjNRTXVrSUx0MmJ6TXZ1alROQi92dEVKNDhuT215MUJHdApDcUl4anJpbUVpSTdEQlNQcmQ3V041bDF4aHg5cEJ5bUJUdE1XR04yam55dHB3amplaitHbmY5UmExb1R6SnFICmhSZWl5STdsYkdVK0EwNUM2Q054RzI0dnNKMGhLaFhWUVBZZ0NDbERjOEY5RCtMQ09TRDUzU25vN0RpTkt6VzQKSHB2TmpVOFh2d0wvYkFHOCtVS25mK3pRYTAxRGF4MnRROVM0SVNUYVpMYU9WWHV2cDJaQjltczBnRlJQcHkweQpUbXl6ZjhHaEUxZG5ZK0kwZnMxTnIyU1lTZ1BPYkpkZk56dkFmWnQvNU1ycmw3a2kxRzU1OWhpNGEyMjRsNlo0CmxBeHJzTWNhb1FuN3pJN0R3MUgyZ3JwVTNPN21kZ25neDhyYTB3LzZGZmtscUs0dURYZkRaQVJiaWhDZHgzd0wKbnl3aVIwbzNhelFEeGRqOExPSm80RGozbU0yK21uMnNEaHJSSm5KRVlvczlwTXRKQkVNQWNqYW5FN0FKWGY0SAoxdldDcjYyeGhITS9od0lEQVFBQm8xQXdUakFkQmdOVkhRNEVGZ1FVZzFOYnNwYkxmZVoxSnd3bkZHcUloUnJ4CkVrQXdId1lEVlIwakJCZ3dGb0FVZzFOYnNwYkxmZVoxSnd3bkZHcUloUnJ4RWtBd0RBWURWUjBUQkFVd0F3RUIKL3pBTkJna3Foa2lHOXcwQkFRc0ZBQU9DQWdFQUhkZW5aNFFHc2o0TXM4aG9qZjNFQlU5ZEx2dTRrOEZibURpSQpUZlliWS9IS1ZPWWRpNVJCUk1MRFNBaWZUck14YnFLVklWQnkrMWYvWVJEcHV0eVFIYzRUcExLS1NqVjNBUXBDClFaa0VTdzFjSHNYZmNWYzErMmJjL2Q5UzJKTjFmYVo3UjhCUFI3cncrS0s1dEVvZjBLV29GVDVUMDFQa2lwREwKZXMwNmVBc0h3Z0luQ2J0bTk1Sk5hbDFZS004ZzA1ZzUxVFFPWGNsSlJlMTM4WHNBdFU4YXhsQnVxN0RyY1FmawpCQ0lEZUQ4eE9CaWtONlNwVjdXdDd6b2RFeVp1QUhscHM3RVNTaEF4eDh4SExBWXZsOGNBam1vcC9WdVA2bzFZCjNSTDZ0VFpPYVlOVS9CWUxKOFpaY04xTHppd0tKeXZseDljZ0FxM0NEUC9iOUVvaTFKVTZGbWxrVm13eGtiblkKdGU2N1lZWk1Rc0ZiMVR5QUxPQ2ZyeWFSR3FmUkNDaDVFWXJsU2IvVWlFTHpWaGg0bWNXbFNYVTZHTDIwbFhrTwo0QlRsRkQwUktnOWRKWUpDaXNCMVJaK2w1Z0ZheWVuY05EdVZBRmdzVmg5eDhBa2xmVjZpZ3JHZUlNTFpwMmNYCndsN3Y3Y3VRWDRMVzRCYlBvOG1xNFNGN0pEVmRaek5lQzU4WndNOTU1cnFhRGFsWW5WN1ZsYkFSbisrRm5mU0sKRzZPSk5LRDNPd3ZIVUVKV0FvVVZEZFh4NEFvYkRBYXNTcXlmQlNpN3B4YzN5MEFObmNNclg2UzRSOTVzOU9nawo3WmJiYXBiUkpIcnkzSW5GZGJJMTZVOEFNcGRTWmIxaDNURkJqYmFKOFhCL3lnUVpGaXZ3a3ZycVFObzUxYXF4CkVrSDBPeVE9Ci0tLS0tRU5EIENFUlRJRklDQVRFLS0tLS0K
---
apiVersion: v1
kind: Service
metadata:
  namespace: cattle-system
  name: cattle-service
  labels:
    app: cattle
spec:
  ports:
  - port: 80
    targetPort: 80
    protocol: TCP
    name: http
  - port: 443
    targetPort: 443
    protocol: TCP
    name: https
  selector:
    app: cattle
---
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  namespace: cattle-system
  name: cattle-ingress-http
  annotations:
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "30"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "1800"   # Max time in seconds for ws to remain shell window open
    nginx.ingress.kubernetes.io/proxy-send-timeout: "1800"   # Max time in seconds for ws to remain shell window open
spec:
  rules:
  - host: rancher.my.org  # FQDN to access cattle server
    http:
      paths:
      - backend:
          serviceName: cattle-service
          servicePort: 80
  tls:
  - secretName: cattle-keys-ingress
    hosts:
    - rancher.my.org      # FQDN to access cattle server
---
kind: Deployment
apiVersion: extensions/v1beta1
metadata:
  namespace: cattle-system
  name: cattle
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: cattle
    spec:
      serviceAccountName: cattle-admin
      containers:
      - image: rancher/rancher:v2.0.8
        imagePullPolicy: Always
        name: cattle-server
        livenessProbe:
          httpGet:
            path: /ping
            port: 80
          initialDelaySeconds: 60
          periodSeconds: 60
        readinessProbe:
          httpGet:
            path: /ping
            port: 80
          initialDelaySeconds: 20
          periodSeconds: 10
        ports:
        - containerPort: 80
          protocol: TCP
        - containerPort: 443
          protocol: TCP
        volumeMounts:
        - mountPath: /etc/rancher/ssl
          name: cattle-keys-volume
          readOnly: true
      volumes:
      - name: cattle-keys-volume
        secret:
          defaultMode: 420
          secretName: cattle-keys-server
EOL
}

resource "local_file" "kube_cluster_yaml" {
  filename = "${path.root}/kube_config_cluster.yml"
  content = "${rke_cluster.cluster.kube_config_yaml}"
}

