import logging
import torch
import azure.functions as func

def main(req: func.HttpRequest) -> func.HttpResponse:
    logging.info('Python HTTP trigger function processed a request.')

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    return func.HttpResponse(f"Status - Torch device is set to {device} .")
