FROM golang:1.10 as builder

ENV GOPATH /go
ENV IMPORT_PATH github.com/joshgav/azure-functions-golang-worker
ENV wd ${GOPATH}/src/${IMPORT_PATH}

WORKDIR $wd
COPY . .

RUN go get -u github.com/golang/dep/...
RUN dep ensure

RUN go build -o golang-worker

# compile HTTP Trigger sample that works without any Azure account
WORKDIR ${wd}/sample/HttpTriggerGo
RUN go build -buildmode=plugin -o bin/HttpTriggerGo.so main.go

# to use a blob-based function you need an Azure storage account
# and to pass the storage key as env to the container - see readme
# if you have a storage, uncomment the next two steps

#WORKDIR ${wd}/sample/HttpTriggerBlobBindingGo
#RUN go build -buildmode=plugin -o bin/HttpTriggerBlobBindingGo.so main.go

#WORKDIR ${wd}/sample/HttpTriggerBlobBindingInOutGo
#RUN go build -buildmode=plugin -o bin/HttpTriggerBlobBindingInOutGo.so main.go

#########

# this is just the Azure Functions Runtime configured to recognize
# .go functions and to start the worker
FROM radumatei/functions-runtime:golang

ENV IMPORT_PATH github.com/joshgav/azure-functions-golang-worker
ENV AzureWebJobsScriptRoot=/app
ENV ASPNETCORE_URLS=http://+:80

# copy the worker in the pre-defined path
COPY --from=builder /go/src/${IMPORT_PATH}/golang-worker /azure-functions-runtime/workers/go/

# copy all samples
COPY --from=builder /go/src/${IMPORT_PATH}/sample/ /app

