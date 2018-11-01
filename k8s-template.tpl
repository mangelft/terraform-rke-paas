CONTEXT = [
  NETWORK = "YES",
  SET_HOSTNAME = "$$NAME",
  SSH_PUBLIC_KEY = "$$USER[SSH_PUBLIC_KEY]",
  USERNAME = "$$UNAME" ]
CPU = "1"
VCPU = "1"
DISK = [
  IMAGE_ID = "7" ]
GRAPHICS = [
  LISTEN = "0.0.0.0",
  TYPE = "VNC" ]
INPUTS_ORDER = ""
LOGO = "images/logos/centos.png"
MEMORY = "2048"
MEMORY_UNIT_COST = "MB"
NIC = [
  NETWORK = "default",
  NETWORK_UNAME = "oneadmin" ]
OS = [
  ARCH = "x86_64",
  BOOT = "" ]

