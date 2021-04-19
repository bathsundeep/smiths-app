This project is a technical demo of deploying a basic Function App to the Azure cloud provider's infrastructure using Terraform. The outcome is an auto-deployed Function App running a packaged HTTP web application within a container in the Azure cloud. 

The "test-function-app" is the Python Azure Function App that lives in `./test-function-app/test-function/*`. This Python and JSON in there comprise the application that will be deployed. Function Apps need some sort of trigger, and this one is triggered by HTTP requests, as described in `__init__.py`. 

The important piece is the Terraform code in `main.tf`. This script does all of the following: 
 1. Describe the Cloud Provider being used (this can be AWS, Azure, GCP, IBM, private, etc). In this case, we are telling Terraform that we are using Azure.

 2. Create a resource group to allocate, and therein manage, the resources in a container within an Azure subscription. You can have different subscriptions or resource groups used for different situations/environments. The storage account is tied to our resource group, which are both tied to the "eastus" region of the Azure cloud.

 3. Create a storage account to store the file system of our container, which will eventually hold the web application that we will execute within the container. The storage account is a unique namespace for this applications data.

 4. Create a storage container. This is different from a storage account. Containers can be used to hold storage blobs within an account. 

 5. Locally archive the `./test-function-app` directory into a .zip file.

 6. Upload the archived file to a storage blob within the storage container on the storage account. A storage account holds storage containers which hold storage blobs.

 7. Create a SAS (Shared Account Signature) so our container can access the uploaded blob in our storage account. We give this SAS read-only permissions since it only needs to read the blob, not upload or change anything.

 8. Create an App Service Plan, which defines the compute resources on the resource_group. Here, we use a Standard Linux Consumption plan, which will give us low cost scalability on a standard platform. 

 9. Finally, we create the Function App itself, using all the Azure resources we have created thus far. We tell the Function App which resource group, app service plan, and storage account to use. Then we tell the function app to loads its website from a URL, which describes the location of our storage blob using storage account, storage container, and the SAS. 


Some commonly used variables exist in `var.tf` to obfuscate implementation details and to supply consistency within the project.

`outputs.tf` describes what will be output to the console after execution of the Terraform script. We will output some details of our Function App that was created during the `main.tf`


To deploy the Function App, all you have to do is:
 1. Having a valid Azure account with a subscription, login to using the Azure CLI command `az login`.

 2. Run `terraform init` to download Terraform dependencies and packages being used by our script.

 3. Run `terraform plan -out plan.tfplan` to create a Terraform plan file that can be applied. This describes exactly what remote resources are being created, modified, or destroyed. Any changes to the `main.tf` will not be reflected in `plan.tfplan` until this command is executed. 

 4. Run `terraform apply plan.tfplan` to execute the plan and deploy the entire app to the Azure cloud.

 5. Optional. Run `terraform plan -destroy -out destroy.tfplan` to create another plan file. This is similar to the `plan.tfplan` file, in that it describes exactly what remote resources are going to be destroyed. Execute this plan with `terraform apply destroy.tfplan`. Terraform will tear down all our cloud resources in reverse order, leaving us with nothing after the end.