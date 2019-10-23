sudo sed -i 's/stacked/'$stack'/gI' terraform.tfvars
export time=$(date +"%m%d%y%H%M%S")
sudo sed -i 's/timestamp/'$time'/gI' terraform.tfvars
sudo sed -i 's/vmname/'$stack_name'/gI' terraform.tfvars
sudo sed -i 's/target_machine/'$machine_type'/gI' terraform.tfvars


terraform init
terraform plan
terraform apply --auto-approve
