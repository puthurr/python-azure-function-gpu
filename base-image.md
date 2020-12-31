
# TODO

## Base image full story

### Linux base Image 

### .Net Core 3.x and PowerShell

### Python Azure Function Runtime

# FROM python:3.7-slim-buster 
# https://github.com/docker-library/python/blob/01b773accc5a2ccb7a4f0d83ec6eb195fe3be655/3.7/buster/slim/Dockerfile


Default Python Azure Function docker images can be found there [Python Azure Functions](https://hub.docker.com/_/microsoft-azure-functions-python)

By looking at the [Python 3.7](https://github.com/Azure/azure-functions-docker/blob/master/host/3.0/buster/amd64/python/python37/python37-appservice.Dockerfile) docker file, I can see the base runtime set to **mcr.microsoft.com/dotnet/core/sdk:3.1**

```docker
# Build the runtime from source
ARG HOST_VERSION=3.0.15149
FROM mcr.microsoft.com/dotnet/core/sdk:3.1 AS runtime-image
ARG HOST_VERSION
```


#### Assembling everything together 

