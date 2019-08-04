Container Elasticity
====================

**Expected Outcome:**

-   300 level understanding of EKS Scaling Patterns.

**Lab Requirements:**

-   an Amazon Elastic Container Service for Kubernetes Cluster with:

    -   `petstore` deployment.

    -   application monitoring has been configured.

-   Cloud9 IDE.

**Average Lab Time:** 15-20 minutes

Introduction
------------

In this module we will take the existing applications you’ve deployed
into your Amazon EKS cluster and demonstrate some of the scaling
capabilities.

Amazon EKS AutoScaling
----------------------

Within a Kubernetes cluster, there are multiple ways to think about
scaling your applications.

1.  Scale the instances running the cluster, this is typically called
    **Cluster AutoScaling**.

2.  **Pod AutoScaling**, typically referred to as Horizontal Pod
    AutoScaling or (**HPA**) for short.

Both Cluster AutoScaling and Horizontal Pod Autoscaling provide
different mechanisms to scale your entire architecture your way. This
module will focus on Cluster Autoscaling.

### Cluster AutoScaling

Cluster autoscaling deals with how many physical EC2 instances are
running in the cluster and how many resource requests are in the
scheduler. How this works, in your `Deployment` you can define CPU and
Memory requests and limits; when you scale this number, it adds up all
the request and verifies it has the capacity to fulfill all the
requests. When you run Cluster Autoscaler it will listen to the
scheduler and when it doesn’t have enough resources it will reconfigure
the desired instance count on the AWS AutoScaling Group causing it to
provision more instances to fulfill the request.

Let’s deploy Cluster Autoscaler to your EKS cluster.

> **Note**
>
> The following section of the module assumes a working EKS cluster,
> created in the **Modern Container Application on EKS** module.

Step 1  
Switch to the tab where you have your Cloud9 `terminal` opened and
change to this modules directory by running:

    cd ~/environment/aws-modernization-workshop-advanced/modules/container-elasticity

Step 2  
Get the autoscaling group name of for the worker nodes and save it for
later use. To do this run the following command:

    ASG=$(aws autoscaling describe-auto-scaling-groups | jq -r '.AutoScalingGroups[] | select((.Tags[].Value == "owned") and (.Tags[].Key == "kubernetes.io/cluster/'$USER_NAME'-petstore")) .AutoScalingGroupName')

    echo "export ASG=${ASG}" >> ~/.bashrc

    echo $ASG

Example Output:

    eksctl-petstore-nodegroup-ng-4897f70e-NodeGroup-1R9B6MYESB2Z1

Step 3  
Open the **cluster-autoscaler.yaml** file by double clicking the
filename in the left-hand navigation in the Cloud9 IDE. The file has the
following contents:

    ---
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      labels:
        k8s-addon: cluster-autoscaler.addons.k8s.io
        k8s-app: cluster-autoscaler
      name: cluster-autoscaler
      namespace: kube-system
    ---
    apiVersion: rbac.authorization.k8s.io/v1beta1
    kind: ClusterRole
    metadata:
      name: cluster-autoscaler
      labels:
        k8s-addon: cluster-autoscaler.addons.k8s.io
        k8s-app: cluster-autoscaler
    rules:
    - apiGroups: [""]
      resources: ["events","endpoints"]
      verbs: ["create", "patch"]
    - apiGroups: [""]
      resources: ["pods/eviction"]
      verbs: ["create"]
    - apiGroups: [""]
      resources: ["pods/status"]
      verbs: ["update"]
    - apiGroups: [""]
      resources: ["endpoints"]
      resourceNames: ["cluster-autoscaler"]
      verbs: ["get","update"]
    - apiGroups: [""]
      resources: ["nodes"]
      verbs: ["watch","list","get","update"]
    - apiGroups: [""]
      resources: ["pods","services","replicationcontrollers","persistentvolumeclaims","persistentvolumes"]
      verbs: ["watch","list","get"]
    - apiGroups: ["extensions"]
      resources: ["replicasets","daemonsets"]
      verbs: ["watch","list","get"]
    - apiGroups: ["policy"]
      resources: ["poddisruptionbudgets"]
      verbs: ["watch","list"]
    - apiGroups: ["apps"]
      resources: ["statefulsets"]
      verbs: ["watch","list","get"]
    - apiGroups: ["storage.k8s.io"]
      resources: ["storageclasses"]
      verbs: ["watch","list","get"]

    ---
    apiVersion: rbac.authorization.k8s.io/v1beta1
    kind: Role
    metadata:
      name: cluster-autoscaler
      namespace: kube-system
      labels:
        k8s-addon: cluster-autoscaler.addons.k8s.io
        k8s-app: cluster-autoscaler
    rules:
    - apiGroups: [""]
      resources: ["configmaps"]
      verbs: ["create"]
    - apiGroups: [""]
      resources: ["configmaps"]
      resourceNames: ["cluster-autoscaler-status"]
      verbs: ["delete","get","update"]

    ---
    apiVersion: rbac.authorization.k8s.io/v1beta1
    kind: ClusterRoleBinding
    metadata:
      name: cluster-autoscaler
      labels:
        k8s-addon: cluster-autoscaler.addons.k8s.io
        k8s-app: cluster-autoscaler
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: ClusterRole
      name: cluster-autoscaler
    subjects:
      - kind: ServiceAccount
        name: cluster-autoscaler
        namespace: kube-system

    ---
    apiVersion: rbac.authorization.k8s.io/v1beta1
    kind: RoleBinding
    metadata:
      name: cluster-autoscaler
      namespace: kube-system
      labels:
        k8s-addon: cluster-autoscaler.addons.k8s.io
        k8s-app: cluster-autoscaler
    roleRef:
      apiGroup: rbac.authorization.k8s.io
      kind: Role
      name: cluster-autoscaler
    subjects:
      - kind: ServiceAccount
        name: cluster-autoscaler
        namespace: kube-system

    ---
    apiVersion: extensions/v1beta1
    kind: Deployment
    metadata:
      name: cluster-autoscaler
      namespace: kube-system
      labels:
        app: cluster-autoscaler
    spec:
      replicas: 1
      selector:
        matchLabels:
          app: cluster-autoscaler
      template:
        metadata:
          labels:
            app: cluster-autoscaler
        spec:
          serviceAccountName: cluster-autoscaler
          containers:
            - image: k8s.gcr.io/cluster-autoscaler:v1.2.2
              name: cluster-autoscaler
              resources:
                limits:
                  cpu: 100m
                  memory: 300Mi
                requests:
                  cpu: 100m
                  memory: 300Mi
              command:
                - ./cluster-autoscaler
                - --v=4
                - --stderrthreshold=info
                - --cloud-provider=aws
                - --skip-nodes-with-local-storage=false
                - --nodes=2:10:<AutoScalingGroupName>
              env:
                - name: AWS_REGION
                  value: us-west-2
              volumeMounts:
                - name: ssl-certs
                  mountPath:  /etc/kubernetes/pki/ca.crt
                  readOnly: true
              imagePullPolicy: "Always"
          volumes:
            - name: ssl-certs
              hostPath:
                path: "/etc/kubernetes/pki/ca.crt"

Step 4  
Replace `<AutoScalingGroupName>` with the output from **Step 2** and
save the new file.

    sed -i "s/<AutoScalingGroupName>/${ASG}/" cluster-autoscaler.yaml

Step 5  
Apply the autoscaling configuration.

    kubectl apply -f cluster-autoscaler.yaml

Expected Output:

    serviceaccount/cluster-autoscaler created
    clusterrole.rbac.authorization.k8s.io/cluster-autoscaler created
    role.rbac.authorization.k8s.io/cluster-autoscaler created
    clusterrolebinding.rbac.authorization.k8s.io/cluster-autoscaler created
    rolebinding.rbac.authorization.k8s.io/cluster-autoscaler created
    deployment.extensions/cluster-autoscaler created

Step 6  
Now we need to configure our instance role to allow it to mutate the
autoscaling group. To do this we need to get our instance role.

    echo $ROLE_NAME

Example Output:

    eksctl-petstore-nodegroup-ng-4897-NodeInstanceRole-5YGEF14MRJVE

> **Important**
>
> If there is no output to the above command, make sure to re-run the
> following commands from the **Container Application Monitoring**
> module. **Command Reference**:
>
>     INSTANCE_PROFILE_NAME=$(aws iam list-instance-profiles | jq -r '.InstanceProfiles[].InstanceProfileName' | grep nodegroup)
>
>     INSTANCE_PROFILE_ARN=$(aws iam get-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME | jq -r '.InstanceProfile.Arn')
>
>     ROLE_NAME=$(aws iam get-instance-profile --instance-profile-name $INSTANCE_PROFILE_NAME | jq -r '.InstanceProfile.Roles[] | .RoleName')
>
>     echo "export ROLE_NAME=${ROLE_NAME}" >> ~/.bash_profile
>
>     echo "export INSTANCE_PROFILE_ARN=${INSTANCE_PROFILE_ARN}" >> ~/.bash_profile
>
> &lt;/div&gt;&lt;/details&gt;

Step 7  
With the output from the cli you can then use the `put-role-policy` AWS
CLI command to enable the Autoscaler with the ability to control the
ASG. In the left-hand navigation pane of the Cloud9 IDE, open the
`modules/container-elasticity/ca-policy.json` file. The file has the
following contents:

    {
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Action": [
                    "autoscaling:DescribeAutoScalingGroups",
                    "autoscaling:DescribeAutoScalingInstances",
                    "autoscaling:DescribeLaunchConfigurations",
                    "autoscaling:DescribeTags",
                    "autoscaling:SetDesiredCapacity",
                    "autoscaling:TerminateInstanceInAutoScalingGroup"
                ],
                "Resource": "*"
            }
        ]
    }

Add the policy to the Instance role by running the following command,
which substitutes the `role-name` from **Step 6**:

    aws iam put-role-policy --policy-name ${USER_NAME}_EksCAPolicy \
    --role-name ${ROLE_NAME} \
    --policy-document file://ca-policy.json

Step 8  
Now let’s see all the pods and see what we have done. View the `kubectl`
log output by running the following command:

    kubectl logs -f deploy/cluster-autoscaler --namespace kube-system -f

Example Output:

    I0824 19:47:24.317676       1 leaderelection.go:199] successfully renewed lease kube-system/cluster-autoscaler
    I0824 19:47:26.329037       1 leaderelection.go:199] successfully renewed lease kube-system/cluster-autoscaler
    I0824 19:47:28.405951       1 leaderelection.go:199] successfully renewed lease kube-system/cluster-autoscaler
    I0824 19:47:28.721876       1 static_autoscaler.go:114] Starting main loop
    I0824 19:47:28.991982       1 utils.go:456] No pod using affinity / antiaffinity found in cluster, disabling affinity predicate for this loop
    I0824 19:47:28.992001       1 static_autoscaler.go:263] Filtering out schedulables
    I0824 19:47:28.992085       1 static_autoscaler.go:273] No schedulable pods
    I0824 19:47:28.992099       1 static_autoscaler.go:280] No unschedulable pods
    I0824 19:47:28.992111       1 static_autoscaler.go:322] Calculating unneeded nodes
    I0824 19:47:29.113364       1 scale_down.go:207] Node ip-192-168-118-217.us-west-2.compute.internal - utilization 0.747000
    I0824 19:47:29.113386       1 scale_down.go:211] Node ip-192-168-118-217.us-west-2.compute.internal is not suitable for removal - utilization too big (0.747000)
    I0824 19:47:29.113395       1 scale_down.go:207] Node ip-192-168-229-57.us-west-2.compute.internal - utilization 0.055000
    I0824 19:47:29.113402       1 scale_down.go:207] Node ip-192-168-129-250.us-west-2.compute.internal - utilization 0.823000
    I0824 19:47:29.113408       1 scale_down.go:211] Node ip-192-168-129-250.us-west-2.compute.internal is not suitable for removal - utilization too big (0.823000)
    I0824 19:47:29.113417       1 scale_down.go:207] Node ip-192-168-170-118.us-west-2.compute.internal - utilization 0.567000
    I0824 19:47:29.113423       1 scale_down.go:211] Node ip-192-168-170-118.us-west-2.compute.internal is not suitable for removal - utilization too big (0.567000)
    I0824 19:47:29.223632       1 static_autoscaler.go:337] ip-192-168-229-57.us-west-2.compute.internal is unneeded since 2018-08-24 19:47:18.29182836 +0000 UTC duration 10.430029291s
    I0824 19:47:29.223668       1 static_autoscaler.go:352] Scale down status: unneededOnly=true lastScaleUpTime=2018-08-24 19:44:18.175190509 +0000 UTC lastScaleDownDeleteTime=2018-08-24 19:37:17.283607196 +0000 UTC lastScaleDownFailTime=2018-08-24 19:37:17.283607245 +0000 UTC schedulablePodsPresent=false isDeleteInProgress=false

In the logs, you can see that it is constantly checking the amount of
nodes and capacity each node has available, if we have too many requests
for resources and not enough available it will provision new nodes for
you. Let’s try this.

Step 9  
First we need to scale our `deployment` using the `scale` subcommand for
`kubectl`. Press `[Ctrl + c]` to stop to stop the logs and run the
following command:

    kubectl scale deploy/frontend --namespace petstore --replicas=10

Expected Output:

    deployment.extensions/frontend scaled

Step 10  
Now we should again log the `cluster-autoscaler` pod and you will see it
has updated the `desired` count of instances to reflect that.

    kubectl logs -f deploy/cluster-autoscaler --namespace kube-system -f

In the logs for this you will see the new nodes being provisioned into
the cluster.

Step 11  
Now that you have seen this application scale up we can scale this down,
but prior to scale down we need to disable scale down on the node
running `cluster-autoscaler` so that it doesn’t fail.

    kubectl annotate node \
    $(kubectl get pod -n kube-system -o jsonpath="{.items[0].spec.nodeName}" -l app=cluster-autoscaler) \
    cluster-autoscaler.kubernetes.io/scale-down-disabled=true

To see this applied you can get the `node` `annotations` using the
following commanbd:

    kubectl get node $(kubectl get pod -n kube-system -o jsonpath="{.items[0].spec.nodeName}" -l app=cluster-autoscaler) -o jsonpath="{.metadata.annotations}"

Expected Output:

    map[cluster-autoscaler.kubernetes.io/scale-down-disabled:true node.alpha.kubernetes.io/ttl:0 volumes.kubernetes.io/controller-managed-attach-detach:true]

Step 12  
Now that we have the instance cordoned from `down scaling` we can then
`scale` the `--replicas` to `2` by issuing the following command:

    kubectl scale deploy/frontend --namespace petstore --replicas=2

Expected Output:

    deployment.extensions/frontend scaled

> **Tip**
>
> Leveraging [Amazon EC2 Spot
> Instances](https://aws.amazon.com/ec2/spot/) is a perfect mechanism to
> scale the cluster when needed **and** do this with [Cost
> Optimization](https://aws.amazon.com/pricing/cost-optimization/) in
> mind. You can find out more information about this from this
> [blog](https://aws.amazon.com/pricing/cost-optimization/) post.

### Horizontal Pod Autoscaling

The other kind of elasticity that you have when you use Kubernetes or
EKS is Horizontal Pod AutoScaling, or HPA for short. This is a
capability where HPA will provision more pods based on the existing pods
being constrained by some resource usually CPU, Memory, Request
Throughput etc. We will not be covering HPA in this workshop, but check
out the official documentation about [Horizontal Pod
Autoscaling](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/).
