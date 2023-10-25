# Define the variable for ingress ports
variable "ingress_ports" {
  type    = list(number)
  default = [80, 80, 443, 443, 22, 22]
}
