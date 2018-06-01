FROM golang:1.10 as builder

ENV GOPATH /go
ENV IMPORT_PATH github.com/joshgav/azure-functions-go-worker
ENV wd ${GOPATH}/src/${IMPORT_PATH}

WORKDIR $wd
COPY . .

RUN apt-get update && apt-get install unzip
RUN make go-worker

# compile HTTP Trigger sample that works without any Azure account
WORKDIR ${wd}/sample/HttpTriggerGo
RUN go build -buildmode=plugin -o bin/HttpTriggerGo.so main.go

# uncomment the next two stanzas to handle Blob events
# an Azure Storage Account is required to handle functions triggered by Blob
# events and the container needs an account key, see README

#WORKDIR ${wd}/sample/HttpTriggerBlobBindingGo
#RUN go build -buildmode=plugin -o bin/HttpTriggerBlobBindingGo.so main.go

#WORKDIR ${wd}/sample/HttpTriggerBlobBindingInOutGo
#RUN go build -buildmode=plugin -o bin/HttpTriggerBlobBindingInOutGo.so main.go

#########

# from https://github.com/joshgav/azure-functions-host/blob/add-go-worker/Dockerfile
FROM joshgav/functions-runtime-go:latest

ENV IMPORT_PATH github.com/joshgav/azure-functions-go-worker
ENV AzureWebJobsScriptRoot=/home/site/wwwroot
ENV ASPNETCORE_URLS=http://+:80
ENV WorkerPath="/azure-functions-runtime/workers/go/"

# copy the worker into the path specified in IWorkerProvider
COPY --from=builder /go/src/${IMPORT_PATH}/go-worker ${WorkerPath}

# copy all samples
COPY --from=builder /go/src/${IMPORT_PATH}/sample/ ${AzureWebJobsScriptRoot}
