Monitoring the Application
==========================

**Expected Outcome:**

-   200 level understanding of Container Healthchecks using EKS.

-   200 level understanding of shipping container logs for to
    CloudWatch.

**Lab Requirements:**

-   Clou9 IDE.

-   Amazon Elastic Container Service for Kubernetes Cluster.

**Average Lab Time:** 45 minutes

Introduction
------------

When it comes to monitoring an application, a key concept to understand
is you need to ensure that the application is working rather than only
looking to see if server or container is running. In this module, we
will go over some key concepts in monitoring and logging and how to
integrate those concepts with our Pet Store application. The module will
focus on Monitoring Healthchecks and leveraging them further using
[Amazon CloudWatch](https://aws.amazon.com/cloudwatch/).

> **Note**
>
> The following section of the module assumes a working EKS cluster,
> created in the **Modern Container Application on EKS** module.

Healthchecks in Amazon EKS
--------------------------

By default, Kubernetes will restart a container if it crashes for any
reason. It uses Liveness and Readiness probes which can be configured
for running a robust application by identifying the healthy containers
to send traffic to and restarting the ones when required.

In this section, we will understand how [liveness and readiness
probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/)
are defined and test the same against different states of a pod. Below
is the high-level description of how these probes work.

-   **Liveness probes** are used in Kubernetes to know when a pod is
    alive or dead. A pod can be in a dead state for different reasons
    while Kubernetes kills and recreates the pod when liveness probe
    does not pass.

-   **Readiness probes** are used in Kubernetes to know when a pod is
    ready to serve traffic. Only when the readiness probe passes, a pod
    will receive traffic from the service. When readiness probe fails,
    traffic will not be sent to a pod until it passes.

We will review some examples in this module to understand different
options for configuring liveness and readiness probes.

### Configuring the Liveness Probe

As with any Amazon EKS or Kubernetes cluster, we will use manifest file
to declaratively deploy a simple liveness probe.

Step 1  
In the Cloud9 IDE ‘terminal\`, ensure you have switched to this modules’
working directory.

    cd ~/environment/aws-modernization-workshop-advanced/modules/monitor-application/

Step 2  
Open the `liveness-app.yaml` file by double clicking the filename in the
left-hand navigation of the Cloud9 IDE. The file has the following
contents:

    apiVersion: v1
    kind: Pod
    metadata:
      name: liveness-app
    spec:
      containers:
      - name: liveness
        image: brentley/ecsdemo-nodejs
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5

Step 3  
Apply the manifest by running this command in your Cloud9 IDE
`terminal`:

    kubectl apply -f liveness-app.yaml

Expected Output:

    pod/liveness-app created

Step 4  
Confirm that the pod is running by executing the following command:

    kubectl get pod liveness-app

Expected Output:

    NAME           READY   STATUS    RESTARTS   AGE
    liveness-app   1/1     Running   0          6s

> **Note**
>
> The number of `RESTARTS` is `0`.

step 5  
Use `kubectl describe` command will show an event history which will
show any probe failures or restarts, as follows:

    kubectl describe pod liveness-app | grep -A20 Events

Expected Output:

      Type    Reason     Age   From                                                  Message
      ----    ------     ----  ----                                                  -------
      Normal  Scheduled  22s   default-scheduler                                     Successfully assigned default/liveness-app to ip-192-168-84-75.us-west-2.compute.internal
      Normal  Pulling    22s   kubelet, ip-192-168-84-75.us-west-2.compute.internal  pulling image "brentley/ecsdemo-nodejs"
      Normal  Pulled     21s   kubelet, ip-192-168-84-75.us-west-2.compute.internal  Successfully pulled image "brentley/ecsdemo-nodejs"
      Normal  Created    21s   kubelet, ip-192-168-84-75.us-west-2.compute.internal  Created container
      Normal  Started    20s   kubelet, ip-192-168-84-75.us-west-2.compute.internal  Started container

Step 6  
We will now introduce a failure inside the docker runtime by sending the
`kill` command, as follows:

    kubectl exec -it liveness-app -- /bin/kill -s SIGUSR1 1

Step 7  
After 40 - 60 seconds, re-run the `kubectl describe` command to view the
`Events` output again and see what actions the `kubelet` took.

Example Output:

      Type     Reason     Age                From                                                  Message
      ----     ------     ----               ----                                                  -------
      Normal   Scheduled  72s                default-scheduler                                     Successfully assigned default/liveness-app to ip-192-168-84-75.us-west-2.compute.internal
      Warning  Unhealthy  36s (x3 over 46s)  kubelet, ip-192-168-84-75.us-west-2.compute.internal  Liveness probe failed: Get http://192.168.85.179:3000/health: net/http: request canceled (Client.Timeout exceeded while awaiting headers)
      Normal   Pulling    6s (x2 over 71s)   kubelet, ip-192-168-84-75.us-west-2.compute.internal  pulling image "brentley/ecsdemo-nodejs"
      Normal   Killing    6s                 kubelet, ip-192-168-84-75.us-west-2.compute.internal  Killing container with id docker://liveness:Container failed liveness probe.. Container will be killed and recreated.
      Normal   Pulled     5s (x2 over 70s)   kubelet, ip-192-168-84-75.us-west-2.compute.internal  Successfully pulled image "brentley/ecsdemo-nodejs"
      Normal   Created    5s (x2 over 70s)   kubelet, ip-192-168-84-75.us-west-2.compute.internal  Created container
      Normal   Started    5s (x2 over 70s)   kubelet, ip-192-168-84-75.us-west-2.compute.internal  Started container

> **Tip**
>
> When the nodejs application entered a debug mode with `SIGUSR1`
> signal, it did not respond to the health check pings and the `kubelet`
> killed the container. The container was subject to the default restart
> policy.

Step 8  
Confirm that the container was restarted by viewing the pod.

    kubectl get pod liveness-app

Expected Output:

    NAME           READY   STATUS    RESTARTS   AGE
    liveness-app   1/1     Running   1          6m42s

> **Note**
>
> The number of `RESTARTS` is now `1`.

### Configuring the Readiness Probe

The `readinessProbe` definition explains how a Linux command can be
configured as healthcheck. We create an empty file called
`/tmp/healthy`, to configure readiness probe and use the same to
understand how kubelet helps to update a deployment with only healthy
pods.

Step 1  
Open the `readiness-deployment.yaml` file by double clicking the
filename in the left-hand navigation of the Cloud9 IDE. The file has the
following contents:

    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: readiness-deployment
    spec:
      replicas: 3
      selector:
        matchLabels:
          app: readiness-deployment
      template:
        metadata:
          labels:
            app: readiness-deployment
        spec:
          containers:
          - name: readiness-deployment
            image: alpine
            command: ["sh", "-c", "touch /tmp/healthy && sleep 86400"]
            readinessProbe:
              exec:
                command:
                - cat
                - /tmp/healthy
              initialDelaySeconds: 5
              periodSeconds: 3

Step 2  
We now create a deployment to test the readiness probe using the
`terminal` in our CLoud9 IDE. The deployment consists of 3 replicas of
the readiness probe.

    kubectl apply -f readiness-deployment.yaml

Step 3  
View the deployment by executing the folloing `kubectl` command:

    kubectl get pods -l app=readiness-deployment

Example Output:

    NAME                                    READY   STATUS    RESTARTS   AGE
    readiness-deployment-6b95b8dd66-dqdzq   0/1     Running   0          8s
    readiness-deployment-6b95b8dd66-tpxll   0/1     Running   0          8s
    readiness-deployment-6b95b8dd66-x2mwn   0/1     Running   0          8s

Step 4  
Confirm that all replicas are available to serve traffic when a service
is pointed to this deployment.

    kubectl describe deployment readiness-deployment | grep Replicas:

Expected Output:

    Replicas:               3 desired | 3 updated | 3 total | 3 available | 0 unavailable

Step 5  
We will now introduce a failure inside the docker runtime by deleting
the `/tmp/healthy` file inside the docker runtime, since this file must
be present in order for the readiness check to pass. Pick one of the 3
available pods from the output of **Step 3** to introduce a failure.
Execute the following command, substituting the name of the pod you’ve
selected instead of the **&lt;YOUR-READINESS-POD-NAME&gt;** placeholder:

    kubectl exec -it <YOUR-READINESS-POD-NAME> -- rm /tmp/healthy

Step 6  
View the deployment once again by running the following command:

    kubectl get pods -l app=readiness-deployment

Expected Output:

    NAME                                    READY   STATUS    RESTARTS   AGE
    readiness-deployment-6b95b8dd66-74msx   0/1     Running   0          53s
    readiness-deployment-6b95b8dd66-k99vl   1/1     Running   0          53s
    readiness-deployment-6b95b8dd66-pwcgc   1/1     Running   0          53s

> **Note**
>
> Traffic will not be routed to the first pod in the above deployment.
> The `READY` column confirms that the readiness probe for this pod did
> not pass and hence was marked as not ready.

Step 7  
We will now check for the replicas that are available to serve traffic
when a service is pointed to this deployment.

    kubectl describe deployment readiness-deployment | grep Replicas:

Expected Output:

    Replicas:               3 desired | 3 updated | 3 total | 2 available | 1 unavailable

When the readiness probe for a pod fails, the endpoints controller
removes the pod from list of endpoints of all services that match the
pod.

> **Tip**
>
> Our Liveness Probe example used `HTTP` request and Readiness Probe
> executed a command to check health of a pod. Same can be accomplished
> using a `TCP` request as described in the
> [documentation](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-probes/).

**Challenge Question: *How would you restore the pod to Ready status?***

**Solution:**

Run the following commands with the name of the pod to recreate the
`/tmp/healthy file`. Once the pod passes the probe, it gets marked as
ready and will begin to receive traffic again.

    kubectl exec -it <YOUR-READINESS-POD-NAME> -- touch /tmp/healthy

    kubectl get pods -l app=readiness-deployment

&lt;/div&gt;&lt;/details&gt;

Understanding Shipping Logs to CloudWatch from EKS
--------------------------------------------------

A typical logging pattern in Kubernetes, and hence EKS is to leverage a
pattern known as the **EFK stack**, which is comprised of:

-   [Fluentd](https://www.fluentd.org/)

-   [Elasticsearch](https://www.elastic.co/products/elasticsearch)

-   [Kibana](https://www.elastic.co/products/kibana)

However, in this part of the module, we will only focus on **Fluentd**
as it will be the mechanism that forwards the logs from the individual
worker nodes in the cluster to the central logging backend, CkoudWatch.
We will be deploying Fluentd as a DaemonSet, or one pod per worker node.
The fluentd log daemon will collect logs and forward to CloudWatch Logs.
This will require the nodes to have permissions to send logs and create
log groups and log streams.

Step 1  
For this part of the module we will need to ensure that the `Role Name`
that the EKS worker nodes use has the necessary policy. Execute the
following commands in the CLoud9 IDE `terminal` to configure the worker
roles variables:

    INSTANCE_PROFILE_NAME=$(aws iam list-instance-profiles | jq -r '.InstanceProfiles[].InstanceProfileName' | grep ${USER_NAME}-petstore-nodegroup)

    INSTANCE_PROFILE_ARN=$(aws iam get-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME | jq -r '.InstanceProfile.Arn')

    ROLE_NAME=$(aws iam get-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME | jq -r '.InstanceProfile.Roles[] | .RoleName')

    echo "export ROLE_NAME=${ROLE_NAME}" >> ~/.bashrc

    echo "export INSTANCE_PROFILE_ARN=${INSTANCE_PROFILE_ARN}" >> ~/.bashrc

Step 2  
Next, we configure a policy for CloudWatch access and apply it to the
worker nodes.

    cat <<EoF > /tmp/eks-logs-policy.json
    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Action": [
                    "logs:DescribeLogGroups",
                    "logs:DescribeLogStreams",
                    "logs:CreateLogGroup",
                    "logs:CreateLogStream",
                    "logs:PutLogEvents"
                ],
                "Resource": "*",
                "Effect": "Allow"
            }
        ]
    }
    EoF

    aws iam put-role-policy --role-name $ROLE_NAME --policy-name ${USER_NAME}_WorkerLogPolicy --policy-document file:///tmp/eks-logs-policy.json

Step 3  
Validate that the policy has been attached to the worker node role.

    aws iam get-role-policy --role-name $ROLE_NAME --policy-name ${USER_NAME}_WorkerLogPolicy

Expected Output:

    {
        "RoleName": "eksctl-petstore-nodegroup-ng-d389-NodeInstanceRole-1E8S9YL9EQ5QI",
        "PolicyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Action": [
                        "logs:DescribeLogGroups",
                        "logs:DescribeLogStreams",
                        "logs:CreateLogGroup",
                        "logs:CreateLogStream",
                        "logs:PutLogEvents"
                    ],
                    "Resource": "*",
                    "Effect": "Allow"
                }
            ]
        },
        "PolicyName": "Logs-Policy-For-Worker"
    }

Step 4  
Now we can deploy Fluentd. To get started, navigate to the folder for
this module and open the `fluentd.yaml` in the Cloud9 IDE. Although it
is a large manifest for deploying Fluentd as a **DaemonSet**, i.e. one
pod per worker node, the log agent configuration is located in the
Kubernetes **ConfigMap** as shown below:

    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: fluentd
      namespace: kube-system
    ---
    apiVersion: rbac.authorization.k8s.io/v1beta1
    kind: ClusterRole
    metadata:
      name: fluentd
      namespace: kube-system
    rules:
    - apiGroups: [""]
      resources:
      - namespaces
      - pods
      verbs: ["get", "list", "watch"]
    ---
    apiVersion: rbac.authorization.k8s.io/v1beta1
    kind: ClusterRoleBinding
    metadata:
      name: fluentd
      namespace: kube-system
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: fluentd
    subjects:
    - kind: ServiceAccount
      name: fluentd
      namespace: kube-system
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: fluentd-config
      namespace: kube-system
      labels:
        k8s-app: fluentd-cloudwatch
    data:
      fluent.conf: |
        @include containers.conf
        @include systemd.conf

        <match fluent.**>
          @type null
        </match>
      containers.conf: |
        <source>
          @type tail
          @id in_tail_container_logs
          @label @containers
          path /var/log/containers/*.log
          pos_file /var/log/fluentd-containers.log.pos
          tag *
          read_from_head true
          <parse>
            @type json
            time_format %Y-%m-%dT%H:%M:%S.%NZ
          </parse>
        </source>

        <label @containers>
          <filter **>
            @type kubernetes_metadata
            @id filter_kube_metadata
          </filter>

          <filter **>
            @type record_transformer
            @id filter_containers_stream_transformer
            <record>
              stream_name ${tag_parts[3]}
            </record>
          </filter>

          <match **>
            @type cloudwatch_logs
            @id out_cloudwatch_logs_containers
            region "#{ENV.fetch('REGION')}"
            log_group_name "/eks/<UserName>/containers"
            log_stream_name_key stream_name
            remove_log_stream_name_key true
            auto_create_stream true
            <buffer>
              flush_interval 5
              chunk_limit_size 2m
              queued_chunks_limit_size 32
              retry_forever true
            </buffer>
          </match>
        </label>
      systemd.conf: |
        <source>
          @type systemd
          @id in_systemd_kubelet
          @label @systemd
          filters [{ "_SYSTEMD_UNIT": "kubelet.service" }]
          <entry>
            field_map {"MESSAGE": "message", "_HOSTNAME": "hostname", "_SYSTEMD_UNIT": "systemd_unit"}
            field_map_strict true
          </entry>
          path /run/log/journal
          pos_file /var/log/fluentd-journald-kubelet.pos
          read_from_head true
          tag kubelet.service
        </source>

        <source>
          @type systemd
          @id in_systemd_kubeproxy
          @label @systemd
          filters [{ "_SYSTEMD_UNIT": "kubeproxy.service" }]
          <entry>
            field_map {"MESSAGE": "message", "_HOSTNAME": "hostname", "_SYSTEMD_UNIT": "systemd_unit"}
            field_map_strict true
          </entry>
          path /run/log/journal
          pos_file /var/log/fluentd-journald-kubeproxy.pos
          read_from_head true
          tag kubeproxy.service
        </source>

        <source>
          @type systemd
          @id in_systemd_docker
          @label @systemd
          filters [{ "_SYSTEMD_UNIT": "docker.service" }]
          <entry>
            field_map {"MESSAGE": "message", "_HOSTNAME": "hostname", "_SYSTEMD_UNIT": "systemd_unit"}
            field_map_strict true
          </entry>
          path /run/log/journal
          pos_file /var/log/fluentd-journald-docker.pos
          read_from_head true
          tag docker.service
        </source>

        <label @systemd>
          <filter **>
            @type record_transformer
            @id filter_systemd_stream_transformer
            <record>
              stream_name ${tag}-${record["hostname"]}
            </record>
          </filter>

          <match **>
            @type cloudwatch_logs
            @id out_cloudwatch_logs_systemd
            region "#{ENV.fetch('REGION')}"
            log_group_name "/eks/<UserName>/systemd"
            log_stream_name_key stream_name
            auto_create_stream true
            remove_log_stream_name_key true
            <buffer>
              flush_interval 5
              chunk_limit_size 2m
              queued_chunks_limit_size 32
              retry_forever true
            </buffer>
          </match>
        </label>
    ---
    apiVersion: extensions/v1beta1
    kind: DaemonSet
    metadata:
      name: fluentd-cloudwatch
      namespace: kube-system
      labels:
        k8s-app: fluentd-cloudwatch
    spec:
      template:
        metadata:
          labels:
            k8s-app: fluentd-cloudwatch
        spec:
          serviceAccountName: fluentd
          terminationGracePeriodSeconds: 30
          # Because the image's entrypoint requires to write on /fluentd/etc but we mount configmap there which is read-only,
          # this initContainers workaround or other is needed.
          # See https://github.com/fluent/fluentd-kubernetes-daemonset/issues/90
          initContainers:
          - name: copy-fluentd-config
            image: busybox
            command: ['sh', '-c', 'cp /config-volume/..data/* /fluentd/etc']
            volumeMounts:
            - name: config-volume
              mountPath: /config-volume
            - name: fluentdconf
              mountPath: /fluentd/etc
          containers:
          - name: fluentd-cloudwatch
            image: fluent/fluentd-kubernetes-daemonset:v1.1-debian-cloudwatch
            env:
              - name: REGION
                value: us-west-2
              - name: CLUSTER_NAME
                value: petstore
            resources:
              limits:
                memory: 200Mi
              requests:
                cpu: 100m
                memory: 200Mi
            volumeMounts:
            - name: config-volume
              mountPath: /config-volume
            - name: fluentdconf
              mountPath: /fluentd/etc
            - name: varlog
              mountPath: /var/log
            - name: varlibdockercontainers
              mountPath: /var/lib/docker/containers
              readOnly: true
            - name: runlogjournal
              mountPath: /run/log/journal
              readOnly: true
          volumes:
          - name: config-volume
            configMap:
              name: fluentd-config
          - name: fluentdconf
            emptyDir: {}
          - name: varlog
            hostPath:
              path: /var/log
          - name: varlibdockercontainers
            hostPath:
              path: /var/lib/docker/containers
          - name: runlogjournal
            hostPath:
              path: /run/log/journal

Step 5  
First we have to update the log\_group\_name so it’s uniquely
identifiable.

    sed -i "s/<UserName>/${USER_NAME}/" ~/environment/aws-modernization-workshop-advanced/modules/monitor-application/fluentd.yml

Step 6  
Apply the manifest to create the fluentd DaemonSet.

> **Note**
>
> Ensure that you are working in this module’s directory. i.e.
> `~/environment/aws-modernization-workshop-advanced/modules/monitor-application`

    kubectl apply -f fluentd.yml

Step 7  
We can confirm that all the pods change to `Running` status by executing
the following command:

    kubectl get pods -w --namespace=kube-system

Example Output:

    NAME                       READY   STATUS    RESTARTS   AGE
    aws-node-k75kc             1/1     Running   0          4h
    aws-node-w9d7n             1/1     Running   0          4h
    coredns-6fdd4f6856-mvlst   1/1     Running   0          4h6m
    coredns-6fdd4f6856-xzc9x   1/1     Running   0          4h6m
    fluentd-cloudwatch-55p6x   1/1     Running   0          21s
    fluentd-cloudwatch-sn25n   1/1     Running   0          21s
    kube-proxy-hgmvw           1/1     Running   0          4h
    kube-proxy-r84rb           1/1     Running   0          4h

Step 8  
Now we can view the CloudWatch log streams for the containers in our
`kube-system`. To do this, open a browser tab and navigate to the
[CloudWatch
Console](https://us-west-2.console.aws.amazon.com/cloudwatch/) and click
**Logs** in the navigation pane. All the CloudWatch Log Groups will be
displayed.

Step 9  
In the **Filter:** box, enter `/eks` and press `[ENTER]` to filter the
Log Group for our EKS cluster. Click on the
`/eks/*[red yellow-background]#<USER_NAME>#*/containers` Log Group.

![Log Group](../../images/cw-logs.png)

Now we can see all the logs for the various containers in our
`kube-system`.

![CloudWatch Streams](../../images/cw-streams.png)

This concludes the **Application Monitoring** module. Please continue to
the next module.
