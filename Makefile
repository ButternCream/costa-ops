.PHONY: apply destroy rebuild

apply:
	terraform apply
	$(eval IP := $(shell terraform output | cut -d " " -f 3 | tr -d '"'))
	ssh-keyscan -H ${IP} >> ~/.ssh/known_hosts
	scp -i ~/.ssh/aws-key deploy.sh ec2-user@${IP}:/home/ec2-user/deploy.sh

destroy:
	terraform destroy

rebuild: destroy apply