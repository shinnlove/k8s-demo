# k8s-demo
A brief description of docker and k8s utilization.


1. 镜像、docker hub与k8s

1.1 镜像的制作

制作一个简单的springboot应用，mvn package成jar包，然后制作一个Dockerfile文件如下：

```Dockerfile

From java:8

MAINTAINER Tony 

ADD springbootdemo-0.0.1-SNAPSHOT.jar springboot.jar

ENV JAVA_VERSION 1.8.0_206u_openjdk_amd64

EXPOSE 8080

RUN ["/bin/bash", "-c", "echo $JAVA_VERSION >> hahaha.txt"]

ENTRYPOINT ["java", "-jar", "./springboot.jar"]

```

镜像容器将会运行SpringBoot应用在8080端口上监听、并对外向宿主机暴露IP。

1.2 镜像编译

使用docker命令拉取镜像、一般有缓存会比较快一些，如Rider构建。

```shell
docker build -t image_name .
```

构建完成后使用命令查看镜像：
docker images

Docker的镜像是保存在本地的、但是如果想要共享一些镜像、我们就需要类似GitHub的仓库。
[Docker Hub](https://hub.docker.com/)是开源的Docker镜像仓库，注册账号后把自己的镜像上传到Hub上。

1.3 打Tag与上传镜像

进项编译后只有类似git提交记录的一个字符串唯一码、不太容易记忆，我们需要对其打标。
一般在Rider上构建后，我们使用发布日期对其进行打标、但是上传到Docker Hub上的镜像需要用仓库名/镜像名:版本来格式化，如：

格式：`docker tag [image_name] [repo/image_name:version]`

```shell
docker tag shinnlove/springboot shinnlove/springboot:latest
```
代表是shinnlove仓库下springboot项目的latest版本。

或者给已有镜像重新打tag：
```shell
docker tag shinnlove/springboot:latest shinnlove/springboot:v2021.1216.6666
```

使用docker images命令查看镜像：

```shell
REPOSITORY             TAG       IMAGE ID       CREATED        SIZE
shinnlove/springboot   latest    6d58abfb67ce   24 hours ago   662MB
```

使用命令推送到远端仓库：

```shell
docker push shinnlove/springboot:latest
```

会返回镜像的文件摘要：

`latest: digest: sha256:401c47c75aab573f09cc0985cd8f4b57e4fe8de6406fbd668f0d1f4214b183ee size: 2419`

然后就可以在Hub上找到自己的镜像了。

[!docker hub images](https://github.com/shinnlove/k8s-demo/blob/main/images/image_1.png "image_1")


2.定义容器目录与服务端目录挂载

定义的`my-springboot-k8s.yaml`结构见[kubernetes demo - self application].

2.1 使用命令应用`pv/pvc/pod/service`如下：

```shell
kubectl apply -f tech_learning/k8s_kt/my-springboot-k8s.yaml
```

输出：
```shell
persistentvolume/tony-volume created
persistentvolumeclaim/tony-volume-claim created
deployment.apps/tony-deployment created
service/tony-service created
```

部署后详细信息：


2.2 获取所有服务`kubectl get services`：

```shell
NAME                TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
kubernetes          ClusterIP   10.96.0.1       <none>        443/TCP          91m
tony-service        NodePort    10.98.73.81     <none>        8080:30003/TCP   28m
```

默认使用`ClusterIP`模式内部访问、但是因为使用了NodePort模式暴露、因此需要使用30000以上的端口。

2.3 使用Events命令查看：

```shell

kubectl get events
kubectl get events | grep redis

LAST SEEN   TYPE      REASON               OBJECT                                    MESSAGE
2m30s       Normal    Scheduled            pod/tony-deployment-565954f978-88r6h      Successfully assigned default/tony-deployment-565954f978-88r6h to minikube
2m29s       Normal    Pulling              pod/tony-deployment-565954f978-88r6h      Pulling image "shinnlove/springboot:latest"
9s          Normal    Pulled               pod/tony-deployment-565954f978-88r6h      Successfully pulled image "shinnlove/springboot:latest" in 2m20.601131357s
9s          Normal    Created              pod/tony-deployment-565954f978-88r6h      Created container tony-springboot
8s          Normal    Started              pod/tony-deployment-565954f978-88r6h      Started container tony-springboot

```

可以看到自己的镜像被拉下来进行了部署。

2.4 查看这个节点的启动日志：

```shell
kubectl logs -f tony-deployment-565954f978-88r6h
```

将会输出标准的springboot启动日志、-f参数与tail -f相同。

2.5 使用kubectl 获取集群信息

```shell
kubectl cluster-info

Kubernetes control plane is running at https://172.16.102.129:8443
CoreDNS is running at https://172.16.102.129:8443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy

```

可以看到集群的对外IP是`172.16.102.129`，因此附带NodePort指定的端口号就能让kube proxy将请求转发到集群内的Pods上。


Extra: 在有服务商模式下，使用服务商的LoadBalancer部署服务：

```shell
kubectl expose deployment tony-deployment --type=LoadBalancer --name=tony-service
```

3.检验minikube与容器目录挂载

使用`minikube ssh`登录`minikube`服务端， 可以看到PVC创建的时候已经将目录/mnt/data/commercialorder创建出来了。

```shell
minikube ssh

cd /mnt/data/commercialorder
echo “hello this is a read me file.” >> readme.md
```

如果在目录下创建readme.md，则使用kubectl exec -it进入相应挂载目录的容器内也是能看到这个文件夹下的readme.md。

在容器Pod的yaml中定义volumeMount.mountPath=/root/app/springboot, 则这个目录是minikube下的目录。

```shell
kubectl exec -it tony-deployment-565954f978-88r6h /bin/bash
cd /root/app/springboot
cat readme.md
```

在容器中输出文件到目录下：

```shell
echo "this is charly from k8s running pods." >> hello.txt
```

也是能在minikube的目录下读取这个文件的。

4. 部署与回滚

当前仓库里的版本：


当前latest版本是6666了，访问/hello/xxx可以输出.

编译一版最新的image，再打tag

```shell
docker tag shinnlove/springboot:latest shinnlove/springboot:v2021.1216.8888
```

将最新镜像push到远端Hub

现在拥有6666和8888版本的两个springboot的jar了。

更新deployment中的镜像版本、注意tony-springboot是container的name属性value

```shell
kubectl set image deployment/tony-deployment tony-springboot=shinnlove/springboot:v2021.1216.8888 --record
```

然后重新发版：

```shell
kubectl rollout status deployment/tony-deployment
```

会发现k8s会逐个更新集群


检查所有部署的版本：

```shell
kubectl rollout history deployment.v1.apps/tony-deployment
```

查看某个历史版本：

```shell
kubectl rollout history deployment.v1.apps/tony-deployment --revision=5
```

回滚到上一个版本：

```shell
kubectl rollout undo deployment.v1.apps/tony-deployment
```

回滚到指定版本：

```shell
kubectl rollout undo deployment.v1.apps/tony-deployment --to-revision=5
```


可以看到5和6版本之间实现了成功的回切：

5版本：


6版本：


特别注意，如果在不同版本之间不停回滚，最后回滚后的版本id会升级、原来的版本会不存在。



在往k8s部署应用的时候，我们会用到pv、pvc日志目录挂载、pods、replica、应用的configmap、部署的deployment、集群的service暴露等各类资源，
有时候甚至需要在initContainer中生成/bin/bash的脚本去初始化一些集群工作和探活，因此手动编写单个yaml文件显得尤为不方便。

因此Helm出现了，他可以把工作目录下的所有yaml文件和脚本一起打包成一个合集Charts、并且可以发布到hub或者repo上方便share。

1.安装helm

```shell
Download from [Helm Official Site](https://github.com/helm/helm/releases)

tar -zxvf helm-v3.7.2-darwin-amd64.tar.gz
ln -s darwin-amd64 helm
```

2. 常用命令

helm -h能看到helm的所有command、后接仓库名或应用。

常用的有：install、uninstall、package、rollback、search、upgrade这几个命令。

2.1 仓库操作

新增仓库

```shell
helm repo add brigade https://brigadecore.github.io/charts
```

查看现有仓库：

```shell
helm repo list

NAME    URL
aliyun  https://kubernetes.oss-cn-hangzhou.aliyuncs.com/charts
stable  http://mirror.azure.cn/kubernetes/charts
apphub  https://apphub.aliyuncs.com
```

加了3个比较常用的仓库。

更新仓库：

```shell
helm repo update
```

查找repo中的charts

如：查看repo/hub中的所有Nignx图表

```shell
helm search repo/hub | grep nginx
```

如：查找repo/hub中的某个图表，如redis

```shell
helm search repo stable/redis
```

2.2 安装、查看与卸载图表

```shell
helm search repo redis / helm search repo stable/redis

NAME                              CHART VERSION APP VERSION DESCRIPTION
stable/prometheus-redis-exporter  3.5.1         1.3.4       DEPRECATED Prometheus exporter for Redis metrics
stable/redis                      10.5.7        5.0.7       DEPRECATED Open source, advanced key-value stor...
stable/redis-ha                   4.4.6         5.0.6       DEPRECATED - Highly available Kubernetes implem...
stable/sensu                      0.2.5         0.28        DEPRECATED Sensu monitoring framework backed by...

```

查看仓库中图表的信息：

```shell
helm inspect values stable/redis
```

执行安装：

```shell
helm install [release-name] [repo/image-name]
helm install my-redis stable/redis
```

卸载图表：

```shell
helm uninstall my-redis
```

2.3 查看图表

查看安装的图表

```shell
helm list -aq
```

查看图表的值[release-name]：

```shell
helm get values my-redis
```

查看安装图表的简要环境变量：

```shell
helm show chart stable/redis
```

安装之后如果要查看更为详细的所有信息、如yaml、events等，可配合kubectl命令查看：

```shell
kubectl describe pod my-redis
kubectl describe pod/my-redis-master-0
```

Visit: [K8S Hub Charts](https://hub.kubeapps.com/charts) for various charts.




