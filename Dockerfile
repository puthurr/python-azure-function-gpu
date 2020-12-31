FROM contoso.azurecr.io/contoso/mrc-full-gpu:latest

ENV AzureWebJobsScriptRoot=/home/site/wwwroot \
    AzureFunctionsJobHost__Logging__Console__IsEnabled=true
# Python Requirements install
COPY requirements.txt /

RUN pip install -r /requirements.txt

# Copy the application files
COPY . /home/site/wwwroot
