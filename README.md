# Project: GPU-Enabled docker image to host a Python PyTorch Azure Function

This goal here is to demonstrate how to build a docker image with GPU enabled (K80), to support a Python Azure Function deployments. 

Azure Function in Python are easy to use, removing some level of complexity to productionize your Python workloads.

For the sake of the demonstrate we will use Azure Kubernetes with a single Standard_NC6 compute with an [NVIDIA Tesla K80](https://www.nvidia.com/content/dam/en-zz/Solutions/Data-Center/tesla-product-literature/Tesla-K80-BoardSpec-07317-001-v05.pdf) under the [NC-Series](https://docs.microsoft.com/en-us/azure/virtual-machines/nc-series). 

> NC-series VMs are powered by the NVIDIA Tesla K80 card and the Intel Xeon E5-2690 v3 (Haswell) processor. Users can crunch through data faster by leveraging CUDA for energy exploration applications, crash simulations, ray traced rendering, deep learning, and more.

This project assumes you have basic understanding of 

- Nvidia CUDA
- Azure Kubernetes 
- Azure CLI 
- Docker
- Azure Function 
- Python / Torch

# Why would I need a Python Azure Function with GPU for? 

Well in my particular scenario, our team wanted to build a Machine Reading Comprehension service for questions answering which we could infuse in many existing customers' solutions. 

One of the major obstacle we faced was GPU-Support for our Python Azure Function hence this project. 

> Machine Reading Comprehension (MRC), or the ability to read and understand unstructured text and then answer questions about it remains a challenging task for computers. MRC is a growing field of research due to its potential in various enterprise applications, as well as the availability of MRC benchmarking datasets (MSMARCO, SQuAD, NewsQA, etc.)

Let's begin.

# Step 1 - Create an Azure Kubernetes (AKS) GPU cluster 

Follow the steps as described in Microsoft official documentation
https://docs.microsoft.com/en-us/azure/aks/gpu-cluster

If you have enough contributor rights on your Azure subscription, try out the new gpu VHD image.  
https://docs.microsoft.com/en-us/azure/aks/gpu-cluster#use-the-aks-specialized-gpu-image-preview

At the end of this step you should have 

- One AKS clsuter running in Azure
- A default pool with one gpu-enabled node

To operate the cluste through kubectl don't forget to get the AKS credentials 
```azcli
az aks get-credentials --resource-group myResourceGroup --name myAKSCluster
```

To validate the GPU is available for scheduling refer to this [section](https://docs.microsoft.com/en-us/azure/aks/gpu-cluster#confirm-that-gpus-are-schedulable) 


# Step 2 - Create an Azure Container Registry (ACR)

[Azure Container Registry](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-get-started-portal) can build any docker images remotely so you don't have to install Docker locally. 

You can push your existing [local images into your ACR.](https://docs.microsoft.com/en-us/azure/container-registry/container-registry-get-started-portal#push-image-to-registry)

You could provision your AKS cluster [with ACR integration directly](https://docs.microsoft.com/en-us/azure/aks/cluster-container-registry-integration#create-a-new-aks-cluster-with-acr-integration).


# Step 3 - Attach your ACR Link it to your AKS cluster.

This step enables the integration between your private container registry and you k8s cluster. 

https://docs.microsoft.com/en-us/azure/aks/cluster-container-registry-integration

```azcli
az aks update -n myAKSCluster -g myResourceGroup --attach-acr <acr-name>
```

**Now you have all the needed services provisioned. You can start building images.**

# Step 4 - Build the base docker image with GPU support 

The base image will provide the following runtime components:
- Ubuntu 18.04
- CUDA Driver 11.1
- .NET Core 3.1.404
- PowerShell 7.0.3
- Azure Function Host runtime 3.0.15149 
- Python 3.7.9

You could easily adapt that base image to refer Python 3.8 or 3.9.

## Build the base image into your Azure container registry

In the directory base-image you will find the base image docker to build. Adjust the image name and registry accordingly. 

```azcli
az acr build --image contoso/mrc-full-gpu --registry contoso.azurecr.io --file mrc-full-gpu.Dockerfile .
```

You may want to validate your base image build.  

## Test the base image

In the yaml directory you will find a [yaml file(/yaml/mrc-full-gpu.yaml) to test your base image.

**Note**
```yaml
        command: ["sleep", "infinity"]
        resources:
          limits:
           nvidia.com/gpu: 1
```

The container will start and wait forever allowing you to connect to it. 

### Connect to your base-image 
```bash
kubectl exec -it <pod-name> -- /bin/bash
```
### Validate NVidia CUDA installation 
```bash
nvidia-smi
```
a typical output should look like the following
```
Thu Dec 31 10:28:40 2020
+-----------------------------------------------------------------------------+
| NVIDIA-SMI 450.51.06    Driver Version: 450.51.06    CUDA Version: 11.1     |
|-------------------------------+----------------------+----------------------+
| GPU  Name        Persistence-M| Bus-Id        Disp.A | Volatile Uncorr. ECC |
| Fan  Temp  Perf  Pwr:Usage/Cap|         Memory-Usage | GPU-Util  Compute M. |
|                               |                      |               MIG M. |
|===============================+======================+======================|
|   0  Tesla K80           Off  | 00007A8B:00:00.0 Off |                    0 |
| N/A   44C    P0    71W / 149W |   1758MiB / 11441MiB |      0%      Default |
|                               |                      |                  N/A |
+-------------------------------+----------------------+----------------------+

+-----------------------------------------------------------------------------+
| Processes:                                                                  |
|  GPU   GI   CI        PID   Type   Process name                  GPU Memory |
|        ID   ID                                                   Usage      |
|=============================================================================|
+-----------------------------------------------------------------------------+
```
nvidia-smi command is described [here](https://developer.download.nvidia.com/compute/DCGM/docs/nvidia-smi-367.38.pdf) 

### Validate your python installation
Run `python -V` and `pip -V` to confirm your python version. 

### Validate the .NET Core installation
```bash
dotnet --version
```
You shall see 3.1.404 as a result. 

Before proceeding to the Azure function section itself, note that the test container will also take full 'ownership' of the GPU your node has so if you want to proceed further, don't forget to delete your test container to free that GPU for your function. 

# Step 5 - Create a Python Azure Function 

The goal here is to create a Python Azure Function utilizing CUDA driver for processing. A Simple way to achieve this is to import PyTorch into our simple python function, where we can validate that torch device has **CUDA** access. The same torch function running on a non-gpu host will show the torch device as **cpu**. 

If you have cloned this repository, you may skip this step as the function is already initialized. 

```bash
func init --worker-runtime python --docker
```

## Add PyTorch requirements
```
azure-functions==1.4.0
torch===1.6.0 -f https://download.pytorch.org/whl/torch_stable.html
torchvision===0.7.0 -f https://download.pytorch.org/whl/torch_stable.html
```

## Review the provided status function

```python
import logging
import torch
import azure.functions as func

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    return func.HttpResponse(f"Status - Torch device is set to {device} .")
```
This simple status function will describe if CUDA is available or not from the function runtime. The function authentication is set to [anonymous](/status/function.json).

## Test your function locally (Optional)

Assuming you aren't running on an NVIDIA CUDA computer, you shall see the torch device set to cpu.
```
Status - Torch device is set to cpu .
```

## Adjust the Docker file according to your base image 

Replace the **FROM** line to refer to your new base image and container registry. 

```docker
FROM contoso.azurecr.io/contoso/mrc-full-gpu:latest

ENV AzureWebJobsScriptRoot=/home/site/wwwroot \
    AzureFunctionsJobHost__Logging__Console__IsEnabled=true
# Python Requirements install
COPY requirements.txt /

RUN pip install -r /requirements.txt

# Copy the application files
COPY . /home/site/wwwroot
```

## Build your function image against your container registry

Under the project directory, 
```azcli
az acr build --image contoso/mrc --registry contoso.azurecr.io --file Dockerfile .
```

# Step 6 - Deploy your function to AKS as DeamonSet

I use deamonset here to simpligy the GPU allocation 1 node = 1 GPU.  Under the yaml directory

```bash
kubectl apply -f mrc.yaml 
```

# Step 7 - Test your function

Capture your service mrc-service public IP from your AKS cluster

```bash
kubectl get services
```
- Hit the base url 
```
http://<mrc-service-public-ip>
```
![Function Home Page](/assets/function-home.png)

- Hit the function url
```
http://<mrc-service-public-ip>/api/status
```
You shall see the below output 
```
Status Torch device cuda
```
Et Voila ! 

**You know extend your Python function to bring Machine Reading Comprehension techniques as a service.**

# Few important points 

- Fractional GPU scheduling is not supported in AKS yet. So each instance of your function will be assigned one GPU. 
- You can scale out by adding new nodes to your pool.
- You can scale up by creating a new pool with higher VMs specifications.
- For non-http-based Azure function you can leverage [KEDA](https://docs.microsoft.com/en-us/azure/azure-functions/functions-kubernetes-keda#supported-triggers-in-keda) for scaling.
- For http-based Azure Function scaling in Kubernetes can be achieved through [Prometheus trigger](https://dev.to/anirudhgarg_99/scale-up-and-down-a-http-triggered-function-app-in-kubernetes-using-keda-4m42).


# DISCLAIMER
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
