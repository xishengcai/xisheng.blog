# distribution

[toc]

## 简介

distribution 又可以称作为 registry v2， v1使用python 写的，提供了容器镜像的存储和分发的功能。

目标是 为构建大型可扩展仓库解决方案提供一种简单、安全、可扩展镜像仓库的基础设施或一个简单的私有镜像仓库。



## distribution 镜像存储目录

```
[root@docker_registry ~]``# tree /var/lib/registry/
/var/lib/registry/
└── docker
  ``└── registry
    ``└── v2
      ``├── blobs
      ``│  └── sha256
      ``│    ├── 13
      ``│    │  └── 13b80a37370b57f558a2e06092c39224e5d1ebac50e48df0afdeb43cf2303e60
      ``│    │    └── data
      ``│    ├── 17
      ``│    │  └── 176bad61a3a435da03ec603d2bd8f7a69286d92f21f447b17f21f0bc4e085bde
      ``│    │    └── data
      ``│    ├── 1b
      ``│    │  └── 1b56fbc8a8e10830867455c0794a70f5469c154cdc013554daf501aeda3f30fe
      ``│    │    └── data
      ``│    ├── 26
      ``│    │  └── 266247e2e603e1c840f97cb4d97a08b9184344e9802966cb42c93d21c407839f
      ``│    │    └── data
      ``│    ├── 3c
      ``│    │  └── 3ce5b8d40451787e1166bf6b207c7834c13f7a0712b46ddbfb591d8b5906bfa6
      ``│    │    └── data
      ``│    ├── 42
      ``│    │  └── 42d8e66fa893de4beb5d136b787cf182b24b7f4972c4212b9493b661ad1d7e85
      ``│    │    └── data
      ``│    ├── 52
      ``│    │  └── 524b0c1e57f8ee5fee01a1decba2f301c324a6513ca3551021264e3aa7341ebc
      ``│    │    └── data
      ``│    ├── 57
      ``│    │  └── 57eade024bfbd48c45ef2bad996c4d6a0fa41b692247294745265af738066813
      ``│    │    └── data
      ``│    ├── 85
      ``│    │  └── 85ecb68de4693bb4093d923f6d1062766e4fa7cbb3bf456a2bc19dd3e6c5e6c6
      ``│    │    └── data
      ``│    ├── b5
      ``│    │  └── b5b4d78bc90ccd15806443fb881e35b5ddba924e2f475c1071a38a3094c3081d
      ``│    │    └── data
      ``│    └── c2
      ``│      └── c2f1d5a9c0a81350fa0ad7e1eee99e379d75fe53823d44b5469eb2eb6092c941
      ``│        └── data
      ``└── repositories
        ``├── centos
        ``│  ├── _layers
        ``│  │  └── sha256
        ``│  │    ├── 524b0c1e57f8ee5fee01a1decba2f301c324a6513ca3551021264e3aa7341ebc
        ``│  │    │  └── link
        ``│  │    └── b5b4d78bc90ccd15806443fb881e35b5ddba924e2f475c1071a38a3094c3081d
        ``│  │      └── link
        ``│  ├── _manifests
        ``│  │  ├── revisions
        ``│  │  │  └── sha256
        ``│  │  │    └── c2f1d5a9c0a81350fa0ad7e1eee99e379d75fe53823d44b5469eb2eb6092c941
        ``│  │  │      └── link
        ``│  │  └── tags
        ``│  │    └── 7
        ``│  │      ├── current
        ``│  │      │  └── link
        ``│  │      └── index
        ``│  │        └── sha256
        ``│  │          └── c2f1d5a9c0a81350fa0ad7e1eee99e379d75fe53823d44b5469eb2eb6092c941
        ``│  │            └── link
        ``│  └── _uploads
        ``└── flannel
          ``├── _layers
          ``│  └── sha256
          ``│    ├── 13b80a37370b57f558a2e06092c39224e5d1ebac50e48df0afdeb43cf2303e60
          ``│    │  └── link
          ``│    ├── 176bad61a3a435da03ec603d2bd8f7a69286d92f21f447b17f21f0bc4e085bde
          ``│    │  └── link
          ``│    ├── 1b56fbc8a8e10830867455c0794a70f5469c154cdc013554daf501aeda3f30fe
          ``│    │  └── link
          ``│    ├── 266247e2e603e1c840f97cb4d97a08b9184344e9802966cb42c93d21c407839f
          ``│    │  └── link
          ``│    ├── 42d8e66fa893de4beb5d136b787cf182b24b7f4972c4212b9493b661ad1d7e85
          ``│    │  └── link
          ``│    ├── 57eade024bfbd48c45ef2bad996c4d6a0fa41b692247294745265af738066813
          ``│    │  └── link
          ``│    └── 85ecb68de4693bb4093d923f6d1062766e4fa7cbb3bf456a2bc19dd3e6c5e6c6
          ``│      └── link
          ``├── _manifests
          ``│  ├── revisions
          ``│  │  └── sha256
          ``│  │    └── 3ce5b8d40451787e1166bf6b207c7834c13f7a0712b46ddbfb591d8b5906bfa6
          ``│  │      └── link
          ``│  └── tags
          ``│    └── v0.12.0-s390x
          ``│      ├── current
          ``│      │  └── link
          ``│      └── index
          ``│        └── sha256
          ``│          └── 3ce5b8d40451787e1166bf6b207c7834c13f7a0712b46ddbfb591d8b5906bfa6
          ``│            └── link
          ``└── _uploads
```



## 相关概念

### mainfest

- `manifest`： 也可以称为 **MANIFEST** 或 **单个 manifest** 或 **普通镜像** 是关于镜像的信息，例如 overylay 层、大小和摘要。
- `manifest lists`: 也可以称为 **MANIFEST_LISTS** 或 **多 manifest** 或 **多架构镜像**，是通过指定一个或多个(理想情况下不止一个)镜像名称创建的镜像层列表。然后，它可以像 `docker pull` 和 `docker run` 命令中的映像名称一样使用。理想情况下，manifest list 是由不同的 CPU 架构 和 OS 操作系统组合的功能相同的镜像创建的。因此，`manifest lists` 通常被称为 “多架构镜像”。

```json
// sample manifest list
{
   "schemaVersion": 2,
   "mediaType": "application/vnd.docker.distribution.manifest.list.v2+json",
   "manifests": [
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 1568,
         "digest": "sha256:d5f25b8d0f6125579cd3ac00a5a6e017ed55721d1b0850a3915da501fe7fd571",
         "platform": {
            "architecture": "amd64",
            "os": "linux"
         }
      },
      {
         "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
         "size": 1776,
         "digest": "sha256:b3e481a692c4fce21591fbaa4d7588bc6de5ae65161b3d7417e255dd22cabb71",
         "platform": {
            "architecture": "arm",
            "os": "linux",
            "variant": "v6"
         }
      }]
  }
```



```go
type ManifestData struct {
    Name          string             `json:"name"`
    Tag           string             `json:"tag"`
    Architecture  string             `json:"architecture"`
    FSLayers      []*FSLayer         `json:"fsLayers"`
    History       []*ManifestHistory `json:"history"`
    SchemaVersion int                `json:"schemaVersion"`
}
```



### Content Digests[🔗](https://docs.docker.com/registry/spec/api/#content-digests)

This API design is driven heavily by [content addressability](http://en.wikipedia.org/wiki/Content-addressable_storage). The core of this design is the concept of a content addressable identifier. It uniquely identifies content by taking a collision-resistant hash of the bytes. Such an identifier can be independently calculated and verified by selection of a common *algorithm*. If such an identifier can be communicated in a secure manner, one can retrieve the content from an insecure source, calculate it independently and be certain that the correct content was obtained. Put simply, the identifier is a property of the content.

To disambiguate from other concepts, we call this identifier a *digest*. A *digest* is a serialized hash result, consisting of a *algorithm* and *hex* portion. The *algorithm* identifies the methodology used to calculate the digest. The *hex* portion is the hex-encoded result of the hash.

We define a *digest* string to match the following grammar:

```
digest      := algorithm ":" hex
algorithm   := /[A-Za-z0-9_+.-]+/
hex         := /[A-Fa-f0-9]+/
```

Some examples of *digests* include the following:

| digest                                                       | description                |
| :----------------------------------------------------------- | :------------------------- |
| sha256:6c3c624b58dbbcd3c0dd82b4c53f04194d1247c6eebdaab7c610cf7d66709b3b | Common sha256 based digest |

## 4+1 视图

### 用例图

![image-20230619102931084](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/image-20230619102931084.png)

### 逻辑视图

![image-20230618102718916](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/image-20230618102718916.png)



### 开发视图

代码仓库位置： https://github.com/distribution/distribution.git 

代码目录结构

![image-20230618104344761](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/image-20230618104344761.png)

![image-20230618104227976](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/image-20230618104227976.png)

程序入口： cmd/registry/main.go

构建 api路由对象的入口： registry/handlers/app.go



### 部署视图

本地运行命令： go run cmd/registry/main.go serve cmd/registry/config-dev.yml





### 运行视图

#### 镜像上传 时序图

![image-20230619101714710](https://soft-package-xisheng.oss-cn-hangzhou.aliyuncs.com/picture/diary/image-20230619101714710.png)



## 核心功能

### 镜像上传

假设使用docker 上传 mysql 镜像

1. docker 先解析本地mysql 镜像，获取要上传的文件layer

2. 判断layer是否已经上传，假设没有

3. 计算 文件摘要 Digest

4. 触发 StartBlobUpload 句柄，开始传送data

   ```go
   // StartBlobUpload begins the blob upload process and allocates a server-side
   // blob writer session, optionally mounting the blob from a separate repository.
   func (buh *blobUploadHandler) StartBlobUpload(w http.ResponseWriter, r *http.Request) {
   	var options []distribution.BlobCreateOption
   	... 省略mount 选项
     
     // Blobs returns a reference to this repository's blob service.
   	blobs := buh.Repository.Blobs(buh)
     
   	// Create allocates a new blob writer to add a blob to this service. The
   	// returned handle can be written to and later resumed using an opaque
   	// identifier. With this approach, one can Close and Resume a BlobWriter
   	// multiple times until the BlobWriter is committed or cancelled.
   	upload, err := blobs.Create(buh, options...)
     ...
   	buh.Upload = upload
   
     // blobUploadResponse provides a standard request for uploading blobs and
   // chunk responses. This sets the correct headers but the response status is
   // left to the caller.
   	if err := buh.blobUploadResponse(w, r); err != nil {
   		buh.Errors = append(buh.Errors, errcode.ErrorCodeUnknown.WithDetail(err))
   		return
   	}
   
   	w.Header().Set("Docker-Upload-UUID", buh.Upload.ID())
   	w.WriteHeader(http.StatusAccepted)
   }
   ```

   

5. progressreader的io.copy 操作会触发registry的PatchBlobData句柄传递具体的data数据

   ```go
   // PatchBlobData writes data to an upload.
   func (buh *blobUploadHandler) PatchBlobData(w http.ResponseWriter, r *http.Request) {
      ct := r.Header.Get("Content-Type")
     。。。
      cr := r.Header.Get("Content-Range")
      cl := r.Header.Get("Content-Length")
   。。。
     
     // copyFullPayload copies the payload of an HTTP request to destWriter. If it
   // receives less content than expected, and the client disconnected during the
   // upload, it avoids sending a 400 error to keep the logs cleaner.
   //
   // The copy will be limited to `limit` bytes, if limit is greater than zero.
      if err := copyFullPayload(buh, w, r, buh.Upload, -1, "blob PATCH"); err != nil {
         buh.Errors = append(buh.Errors, errcode.ErrorCodeUnknown.WithDetail(err.Error()))
         return
      }
   
   // blobUploadResponse provides a standard request for uploading blobs and
   // chunk responses. This sets the correct headers but the response status is
   // left to the caller.
      if err := buh.blobUploadResponse(w, r); err != nil {
         buh.Errors = append(buh.Errors, errcode.ErrorCodeUnknown.WithDetail(err))
         return
      }
   
      w.WriteHeader(http.StatusAccepted)
   }
   ```

6. layerUpload.Commit(context.Background(), distribution.Destriptor{ Digest: digest }) 调用PutBlobUploadComlete句柄完成上传。

```go
// Commit marks the upload as completed, returning a valid descriptor. The
// final size and digest are checked against the first descriptor provided.
func (bw *blobWriter) Commit(ctx context.Context, desc distribution.Descriptor) (distribution.Descriptor, error) {
   dcontext.GetLogger(ctx).Debug("(*blobWriter).Commit")

   if err := bw.fileWriter.Commit(); err != nil {
      return distribution.Descriptor{}, err
   }

   bw.Close()
   desc.Size = bw.Size()

   canonical, err := bw.validateBlob(ctx, desc)
   if err != nil {
      return distribution.Descriptor{}, err
   }

   if err := bw.moveBlob(ctx, canonical); err != nil {
      return distribution.Descriptor{}, err
   }

   if err := bw.blobStore.linkBlob(ctx, canonical, desc.Digest); err != nil {
      return distribution.Descriptor{}, err
   }

   if err := bw.removeResources(ctx); err != nil {
      return distribution.Descriptor{}, err
   }

   err = bw.blobStore.blobAccessController.SetDescriptor(ctx, canonical.Digest, canonical)
   if err != nil {
      return distribution.Descriptor{}, err
   }

   bw.committed = true
   return canonical, nil
}
```



7.完成所有镜像文件传输，再上传manifest数据。



### 镜像下载

未写，待续。。。





## 相关接口

A list of methods and URIs are covered in the table below:

| Method | Path                               | Entity               | Description                                                  |
| :----- | :--------------------------------- | :------------------- | :----------------------------------------------------------- |
| GET    | `/v2/`                             | Base                 | Check that the endpoint implements Docker Registry API V2.   |
| GET    | `/v2/<name>/tags/list`             | Tags                 | Fetch the tags under the repository identified by `name`.    |
| GET    | `/v2/<name>/manifests/<reference>` | Manifest             | Fetch the manifest identified by `name` and `reference` where `reference` can be a tag or digest. A `HEAD` request can also be issued to this endpoint to obtain resource information without receiving all data. |
| PUT    | `/v2/<name>/manifests/<reference>` | Manifest             | Put the manifest identified by `name` and `reference` where `reference` can be a tag or digest. |
| DELETE | `/v2/<name>/manifests/<reference>` | Manifest             | Delete the manifest or tag identified by `name` and `reference` where `reference` can be a tag or digest. Note that a manifest can *only* be deleted by digest. |
| GET    | `/v2/<name>/blobs/<digest>`        | Blob                 | Retrieve the blob from the registry identified by `digest`. A `HEAD` request can also be issued to this endpoint to obtain resource information without receiving all data. |
| DELETE | `/v2/<name>/blobs/<digest>`        | Blob                 | Delete the blob identified by `name` and `digest`            |
| POST   | `/v2/<name>/blobs/uploads/`        | Initiate Blob Upload | Initiate a resumable blob upload. If successful, an upload location will be provided to complete the upload. Optionally, if the `digest` parameter is present, the request body will be used to complete the upload in a single request. |
| GET    | `/v2/<name>/blobs/uploads/<uuid>`  | Blob Upload          | Retrieve status of upload identified by `uuid`. The primary purpose of this endpoint is to resolve the current status of a resumable upload. |
| PATCH  | `/v2/<name>/blobs/uploads/<uuid>`  | Blob Upload          | Upload a chunk of data for the specified upload.             |
| PUT    | `/v2/<name>/blobs/uploads/<uuid>`  | Blob Upload          | Complete the upload specified by `uuid`, optionally appending the body as the final chunk. |
| DELETE | `/v2/<name>/blobs/uploads/<uuid>`  | Blob Upload          | Cancel outstanding upload processes, releasing associated resources. If this is not called, the unfinished uploads will eventually timeout. |
| GET    | `/v2/_catalog`                     | Catalog              | Retrieve a sorted, json list of repositories available in the registry. |

The detail for each endpoint is covered in the following sections.

1. Existing Layers

   The existence of a layer can be checked via a `HEAD` request to the blob store API. The request should be formatted as follo

   ```
   HEAD /v2/<name>/blobs/<digest>
   ```

   If the layer with the digest specified in `digest` is available, a 200 OK response will be received, with no actual body content (this is according to http specification). The response will look as follows:

   ```
   200 OK
   Content-Length: <length of blob>
   Docker-Content-Digest: <digest>
   ```

   When this response is received, the client can assume that the layer is already available in the registry under the given name and should take no further action to upload the layer. Note that the binary digests may differ for the existing registry layer, but the digests will be guaranteed to match.

2. Uploading the Layer

   If the POST request is successful, a `202 Accepted` response will be returned with the upload URL in the `Location` header:

   ```
   202 Accepted
   Location: /v2/<name>/blobs/uploads/<uuid>
   Range: bytes=0-<offset>
   Content-Length: 0
   Docker-Upload-UUID: <uuid>
   ```

   The rest of the upload process can be carried out with the returned url, called the “Upload URL” from the `Location` header. All responses to the upload url, whether sending data or getting status, will be in this format. Though the URI format (`/v2/<name>/blobs/uploads/<uuid>`) for the `Location` header is specified, clients should treat it as an opaque url and should never try to assemble it. While the `uuid` parameter may be an actual UUID, this proposal imposes no constraints on the format and clients should never impose any.

   

   If clients need to correlate local upload state with remote upload state, the contents of the `Docker-Upload-UUID` header should be used. Such an id can be used to key the last used location header when implementing resumable uploads.

   ```
   入口函数 hub.StartblobUpload,
   
   ​	在目录_upload/repository.id/startedad 文件写入 时间
   
   ​	构建 BlobWriter
   ```

   

3. Upload Progress

   The progress and chunk coordination of the upload process will be coordinated through the `Range` header. While this is a non-standard use of the `Range` header, there are examples of [similar approaches](https://developers.google.com/youtube/v3/guides/using_resumable_upload_protocol) in APIs with heavy use. For an upload that just started, for an example with a 1000 byte layer file, the `Range` header would be as follows:

   ```
   Range: bytes=0-0
   ```

   To get the status of an upload, issue a GET request to the upload URL:

   ```
   GET /v2/<name>/blobs/uploads/<uuid>
   Host: <registry host>
   ```

   The response will be similar to the above, except will return 204 status:

   ```
   204 No Content
   Location: /v2/<name>/blobs/uploads/<uuid>
   Range: bytes=0-<offset>
   Docker-Upload-UUID: <uuid>
   ```

   Note that the HTTP `Range` header byte ranges are inclusive and that will be honored, even in non-standard use cases.

   ```
   	解析上一步返回的_state 信息
   
   ​ 关闭上一步中的upload 文件
   
   ​	copy request data to _upload/repository.id/data
   
   ​ 生成下一个请求的URL
   ```

   ​	

4. Monolithic Upload

   A monolithic upload is simply a chunked upload with a single chunk and may be favored by clients that would like to avoided the complexity of chunking. To carry out a “monolithic” upload, one can simply put the entire content blob to the provided URL:

   ```
   PUT /v2/<name>/blobs/uploads/<uuid>?digest=<digest>
   Content-Length: <size of layer>
   Content-Type: application/octet-stream
   
   <Layer Binary Data>
   ```

   The “digest” parameter must be included with the PUT request. Please see the [*Completed Upload*](https://docs.docker.com/registry/spec/api/#completed-upload) section for details on the parameters and expected responses.

   ```
   bw.fileWrite.Commit() 将文件内容buf 刷新。然后检验sha256编码与文件本身是否合法
   
   ​	删除 _uploads 目录下的临时文件
   
   ​	move 临时文件 至 blob/sha256:***
   ```

   

   

5. Pushing an Image Manifest

   Once all of the layers for an image are uploaded, the client can upload the image manifest. An image can be pushed using the following request format:

   ```
   PUT /v2/<name>/manifests/<reference>
   Content-Type: <manifest media type>
   
   {
      "name": <name>,
      "tag": <tag>,
      "fsLayers": [
         {
            "blobSum": <digest>
         },
         ...
       ]
      ],
      "history": <v1 images>,
      "signature": <JWS>,
      ...
   }
   ```

   The `name` and `reference` fields of the response body must match those specified in the URL. The `reference` field may be a “tag” or a “digest”. The content type should match the type of the manifest being uploaded, as specified in [manifest-v2-1.md](https://docs.docker.com/registry/spec/manifest-v2-1/) and [manifest-v2-2.md](https://docs.docker.com/registry/spec/manifest-v2-2/).

   If there is a problem with pushing the manifest, a relevant 4xx response will be returned with a JSON error message. Please see the [*PUT Manifest*](https://docs.docker.com/registry/spec/api/#put-manifest) section for details on possible error codes that may be returned.

   If one or more layers are unknown to the registry, `BLOB_UNKNOWN` errors are returned. The `detail` field of the error response will have a `digest` field identifying the missing blob. An error is returned for each unknown blob. The response format is as follows:

   ```
   {
       "errors": [{
               "code": "BLOB_UNKNOWN",
               "message": "blob unknown to registry",
               "detail": {
                   "digest": <digest>
               }
           },
           ...
       ]
   }
   ```

   

   ## reference

   - [docker hub registry api v2](https://docs.docker.com/registry/spec/api/)
   - [docker push source code analyze](https://blog.csdn.net/Daniel_greenspan/article/details/78855661)
   - [image-index specified](https://github.com/opencontainers/image-spec/blob/main/image-index.md)

   ​	 
