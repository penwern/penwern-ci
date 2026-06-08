variable  "name"{
type=string
default ="penwern"
}
output "greeting" {
value="hello ${var.name}"
}
