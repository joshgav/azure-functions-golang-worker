Azure Functions Go Worker
=========================

![circle](https://circleci.com/gh/Azure/azure-functions-go-worker.png?style=shield&circle-token=:circle-token)

This project provides a Go worker for the Azure Functions runtime.

Background
----------

The Azure Functions runtime supports languages through embedded implementations
of `IWorkerProvider` as described in
[azure-functions-host/wiki/Language-Extensibility](https://github.com/Azure/azure-functions-host/wiki/Language-Extensibility).
An IWorkerProvider for Go is included in a fork of
[azure-functions-host](https://github.com/Azure/azure-functions-host) at
[github.com/joshgav/azure-functions-host:add-go-worker](https://github.com/joshgav/azure-functions-host/tree/add-go-worker).
A built image is available as `joshgav:functions-runtime-go:latest` from
[hub.docker.com](https://hub.docker.com/r/joshgav/functions-runtime-go/).

Of course, in addition to a worker provider we need an actual worker, and that
is provided in this repo. Thus to build a working runtime with Go support
follow these steps:

- `docker build -t azure-functions-go-sample .` 
- `docker run -p 81:80 -it azure-functions-go-sample`

Then, if you go to `localhost:81/api/HttpTriggerGo`, your `Run` method from the
sample should be executed.

If you have an Azure storage account and want to run the blob binding sample,
then uncomment the following lines from the Dockerfile:

```
#WORKDIR /go/src/github.com/radu-matei/azure-functions-golang-worker/sample/HttpTriggerBlobBindingGo
#RUN go build -buildmode=plugin -o bin/HttpTriggerBlobBindingGo.so main.go
```

as well as:

```
#WORKDIR /go/src/github.com/radu-matei/azure-functions-golang-worker/sample/HttpTriggerBlobBindingInOutGo
#RUN go build -buildmode=plugin -o bin/HttpTriggerBlobBindingInOutGo.so main.go
```

> They are commented as when started, the runtime tries to connect to the
> storage account - if the storage account key is not present, it will fail

Then, you need to pass the storage account key when starting the container:

`docker run -p 81:80 -e AzureWebJobsStorage=DefaultEndpointsProtocol="your-storage-account-key" azure-functions-go-sample`


Let's see how a blob binding function looks like - first, `function.json`:

```json
{
  "entryPoint": "Run",
  "bindings": [
    {
      "authLevel": "anonymous",
      "type": "httpTrigger",
      "direction": "in",
      "name": "req"
    },
    {
      "name": "inBlob",
      "type": "blob",
      "direction": "in",
      "path": "demo/{inblobname}",
      "connection": "AzureWebJobsStorage"
    },
    {
      "name": "outBlob",
      "type": "blob",
      "direction": "out",
      "path": "demo/{outblobname}",
      "connection": "AzureWebJobsStorage"
    }
  ],
  "disabled": false
}
```

Things to notice:

- `entryPoint` - this is the name of the function used as entrypioint
- `inBlob` - `in` blob binding - when executed, the runtime will search for a serialized key-value pair, with the key `inblobname` and will give as input data to your function the contents of the blob specified by `inblobname` - we easily pass this as a query string in the HTTP request
- `outBlob` - we want to write something to this blob (and create it if it doesn't exist) - the name of the blob to create is passed the same as for `inblobname`, through a query string

Now let's see the Golang function:

```go
package main

import (
	log "github.com/Sirupsen/logrus"
	"github.com/radu-matei/azure-functions-golang-worker/azfunc"
)

// Run is the entrypoint to our Go Azure Function - if you want to change it, see function.json
func Run(req *azfunc.HTTPRequest, inBlob *azfunc.Blob, outBlob *azfunc.Blob, ctx *azfunc.Context) BlobData {
	log.SetLevel(log.DebugLevel)

	log.Debugf("function id: %s, invocation id: %s", ctx.FunctionID, ctx.InvocationID)

	d := BlobData{
		Name: req.Query["name"],
		Data: inBlob.Data,
	}

	outBlob.Data = "Leeeet's hope this doesn't miserably fail..."

	return d
}

// BlobData mocks any struct (or pointer to struct) you might want to return
type BlobData struct {
	Name string
	Data string
}

```

Things to notice:

- we can use any vendored dependencies we might have available at compile time (everything is packaged as a Golang plugin)
- the name of the function is `Run` - can be changed, just remember to do the same in `function.json`
- the function signature - `func Run(req *azfunc.HTTPRequest, inBlob *azfunc.Blob, outBlob *azfunc.Blob, ctx *azfunc.Context) BlobData` - based on the `function.json`, `req`, `inBlob`, `outBlob` and `ctx` are automatically populated by the worker

> **The content of the parameters is populated based on the name of the parameter! You can change the order, but the name has to be consistent with the name of the binding defined in `function.json`!**

- you can have a return type from the function that, in the case of the `HTTPTrigger` is packaged back as the response body - [the discussion regarding idiomatic return types is still open](https://github.com/radu-matei/azure-functions-golang-worker/issues/4)

- `outBlob` is an output binding - after the function is executed, the contents of the `outBlob` object is marshaled and sent back to the function runtime


Calling that function:

Accessing http://localhost:81/api/HttpTriggerBlobBindingInOutGo?inblobname=your-input-blob&outblobname=your-output-blob&name=gopher, the function will receive as `inBlob` the contents of `your-input-blob` and will write some string in `your-output-blob`, returning a response body back to the HTTP response.



Disclaimer
----------
This is not an official Azure Project - it is an unofficial project to support native Golang in Azure Functions by implementing the Worker for v2 - [more details here](https://github.com/Azure/azure-webjobs-sdk-script/wiki/Language-Extensibility)

It is not officially supported by Microsoft and it is not guaranteed to be supported or even work.
