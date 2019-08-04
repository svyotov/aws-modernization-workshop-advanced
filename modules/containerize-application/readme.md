Modern Container Application on EKS
===================================

**Expected Outcome:**

-   Build the Pet Store application within a Container.

-   Deploy the Pet Store application to a Wildfly based Application
    Server.

**Lab Requirements:** Cloud9 IDE

**Average Lab Time:** 30-45 minutes

Introduction
------------

The Pet Store application is a Java 7 based application that runs on top
of the Wildfly (JBoss) application server. The application is built
using Maven. We will walk through the steps to build the application
using a Maven container then deploy our WAR file to the Wildfly
container. We will be using multi-stage builds to facilitate creating a
minimal docker container.

Then we will push the container to [Amazon Elastic Container Registry
(ECR)](https://aws.amazon.com/ecr/) and finally deploy it to [Amazon
Elastic Container Service for Kubernetes (Amazon
EKS)](http://aws.amazon.com/eks/).

Building the Dockerfile
-----------------------

Step 1  
To get started, switch to the `containerize-application` folder within
this repository.

    cd ~/environment/aws-modernization-workshop-advanced/modules/containerize-application/

Step 2  
Double-click to open the `Dockerfile` in the Cloud9 editor, using the
**Environment** navigation pane, as shows below:

![Dockerfile](../../images/dockerfile-nav.png)

The first stage of our Dockerfile will be to build the application. We
will use the `maven:3.5-jdk-7` container from Docker Hub as our base
image. The first stage of our Dockerfile will need to copy the code into
the container, install the dependencies, then build the application
using Maven.

The second stage of our Dockerfile will be to build our Wildfly
application server. We will need to copy the WAR file we created in the
first stage to the second stage. The WAR file is built to
`/usr/src/app/target/applicationPetstore.war` in the first stage. We
will instruct docker to copy that WAR file to the
`/opt/jboss/wildfly/standalone/deployments/applicationPetstore.war` in
the new stage. We will also have docker copy the `standalone.xml` file
to the proper location
`/opt/jboss/wildfly/standalone/configuration/standalone.xml`. Wildfly
will deploy that application on boot.

The **jPetstore** application requires the **PostrgeSQL** driver. We
install that during image build by declaring a `RUN` statement in the
Dockerfile.

Step 3  
To build the application we will execute the following Docker commands
from the `terminal` in our CLoud9 IDE. Make sure the terminal session
current working directory is
`~/environment/aws-modernization-workshop-advanced/modules/containerize-application/`
working directory, by running the following command in the Cloud9 IDE
`terminal`.

    docker build -t containerize-application_petstore:latest .

> **Note**
>
> The container build should take around 15 minutes complete.

Step 4  
As mentioned, the **jPetstore** application requires a database. We will
use the official **PostgreSQL** image available from Docker Hub. The
following command will pull the official image.

    docker pull postgres:9.6

Step 5  
We can review that we have the all the necessary container images by
running the following command:

    docker images

Example Output:

    REPOSITORY                          TAG                 IMAGE ID            CREATED             SIZE
    containerize-application_petstore   latest              7582d2850ea5        6 minutes ago       804MB
    postgres                            9.6                 8d9572468d97        12 days ago         230MB
    lambci/lambda                       python3.6           420212d009b3        5 weeks ago         1.03GB
    lambci/lambda                       python2.7           7a436931435e        5 weeks ago         901MB
    lambci/lambda                       nodejs4.3           c0914066d9a8        5 weeks ago         931MB
    lambci/lambda                       nodejs6.10          74b405a65ed4        5 weeks ago         946MB
    lambci/lambda                       nodejs8.10          edf1f613772c        5 weeks ago         960MB
    jboss/wildfly                       11.0.0.Final        a12aa93a45f7        3 months ago        700MB
    maven                               3.5-jdk-7           5f03adaf2bbf        7 months ago        483MB

Push the application containers to ECR
--------------------------------------

Next, we’re going to take our already containerized applications and
push them to [Amazon Elastic Container Registry
(ECR)](https://aws.amazon.com/ecr/). Amazon ECR is a fully-managed
Docker container registry that makes it easy for developers to store,
manage, and deploy Docker container images. Amazon ECR is integrated
with Amazon Elastic Container Service (ECS), simplifying your
development to production workflow.

### Deploy ECR Repositories

We will first deploy our CloudFormation template which configures our
ECR Repositories.

CloudFormation creates the following resources:

-   `PetStorePostgreSQLRepository` - ECR Respository for PostgresSQL
    containers.

-   `PetStoreFrontendRepository` - ECR Repository for the front-end
    containers.

Step 1  
We need to replace the placeholder for user name in the template file,
so as to distinguish your ECR Repository from those used by the other
Workshop attendees. The following command will replace the
**&lt;UserName&gt;** parameter with your unique user name.

    sed -i "s/<UserName>/${USER_NAME}/" ~/environment/aws-modernization-workshop-advanced/modules/containerize-application/petstore-ecr-cf-resources.yaml

Step 2  
Using the Cloud9 IDE `terminal`, deploy the CloudFormation template
using the `aws cli` tool.

    aws cloudformation create-stack --stack-name "${USER_NAME}-petstore-ecr" \
    --template-body file://petstore-ecr-cf-resources.yaml \
    --capabilities CAPABILITY_NAMED_IAM

Step 3  
Wait for the Template to finish deploying byt running the following
command:

    until [[ `aws cloudformation describe-stacks --stack-name "${USER_NAME}-petstore-ecr" --query "Stacks[0].[StackStatus]" --output text` == "CREATE_COMPLETE" ]]; do  echo "The stack is NOT in a state of CREATE_COMPLETE at `date`";   sleep 30; done && echo "The Stack is built at `date` - Please proceed"

#### Pushing the Petstore images to Amazon Elastic Container Registry (ECR)

Now that we have created our ECR Repositories, we can push our Petstore
images.

Step 1  
Log into your Amazon ECR registry using the helper provided by the
AWS CLI.

<!-- -->

    $(aws ecr get-login --no-include-email)

> **Note**
>
> Ignore any `WARNING` messages.

Step 2  
Use the AWS CLI to get information about the two Amazon ECR repositories
that were created for you by the CloudFormation template. One repository
will be for the Petstore PostgreSQL backend and the other will be for
the Petstore web frontend.

    aws ecr describe-repositories --repository-name ${USER_NAME}-petstore_postgres ${USER_NAME}-petstore_frontend

Example output:

    {
        "repositories": [
            {
                "registryId": "123456789012",
                "repositoryName": "petstore_postgres",
                "repositoryArn": "arn:aws:ecr:us-west-2:123456789012:repository/petstore_postgres",
                "createdAt": 1533757748.0,
                "repositoryUri": "123456789012.dkr.ecr.us-west-2.amazonaws.com/petstore_postgres"
            },
            {
                "registryId": "123456789012",
                "repositoryName": "petstore_frontend",
                "repositoryArn": "arn:aws:ecr:us-west-2:123456789012:repository/petstore_frontend",
                "createdAt": 1533757751.0,
                "repositoryUri": "123456789012.dkr.ecr.us-west-2.amazonaws.com/petstore_frontend"
            }
        ]
    }

Step 3  
Tag the local docker images with the locations of the remote ECR
repositories we created using our CloudFormation template.

    docker tag postgres:9.6 $(aws ecr describe-repositories --repository-name ${USER_NAME}-petstore_postgres --query=repositories[0].repositoryUri --output=text):latest

    docker tag containerize-application_petstore:latest $(aws ecr describe-repositories --repository-name ${USER_NAME}-petstore_frontend --query=repositories[0].repositoryUri --output=text):latest

Step 4  
Once the images have been tagged, push them to the remote repository.

    docker push $(aws ecr describe-repositories --repository-name ${USER_NAME}-petstore_postgres --query=repositories[0].repositoryUri --output=text):latest

    docker push $(aws ecr describe-repositories --repository-name ${USER_NAME}-petstore_frontend --query=repositories[0].repositoryUri --output=text):latest

You should see the Docker images being pushed with an output similar to
this:

    The push refers to repository [<REDACTED>.dkr.ecr.us-west-2.amazonaws.com/petstore_postgres]
    7856d1f55b98: Pushed
    a125032aca95: Pushed
    fcfc309521a9: Pushed
    4c4e9f97ac56: Pushed
    109402c6a817: Pushed
    6663c6c0d308: Pushed
    ed4da41a79a9: Layer already exists
    7c050956ab95: Layer already exists
    c6fcee3b341c: Layer already exists
    998e6abcfae7: Layer already exists
    df9515382700: Layer already exists
    0fae9a7d0574: Layer already exists
    add4404d0b51: Layer already exists
    cdb3f9544e4c: Layer already exists
    latest: digest: sha256:ca39b6107978303706aac0f53120879afcd0d4b040ead7f19e8581b81c19ecea size: 3243

Deploying to EKS
----------------

With the images pushed to Amazon ECR we are ready to deploy them to our
orchestrator. Next, we will show you how to leverage [Amazon
EKS](https://aws.amazon.com/eks/) to orchestrate our containers into
production.

![ECS](../../images/eks.png)

### Getting Started with Amazon Elastic Container Service for Kubernetes (EKS)

Before we get started, here are some terms you need to understand in
order to deploy your application when creating your first Amazon EKS
cluster.

<table>
<colgroup>
<col style="width: 50%" />
<col style="width: 50%" />
</colgroup>
<thead>
<tr class="header">
<th>Object</th>
<th>Cluster</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td><p><strong>Cluster</strong></p></td>
<td><p>A group of EC2 instances that are all running <code>kubelet</code> which connects into the master control plane.</p></td>
</tr>
<tr class="even">
<td><p><strong>Deployment</strong></p></td>
<td><p>Configuration file that declares how a container should be deployed including how many <code>replicas</code> what the <code>port</code> mapping should be and how it is <code>labeled</code>.</p></td>
</tr>
<tr class="odd">
<td><p><strong>Service</strong></p></td>
<td><p>Configuration file that declares the ingress into the container, these can be used to create Load Balancers automatically.</p></td>
</tr>
</tbody>
</table>

#### Amazon EKS and Kubernetes Manifests

To use Amazon EKS or any Kubernetes cluster you must write a manifest or
a config file, these config files are used to declaratively document
what is needed to deploy an individual application. More information can
be found
[here](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/).

Step 1  
Open the `petstore-eks-manifest.yaml` file by double clicking the
filename in the left-hand navigation of the Cloud9 IDE. The file has the
following contents:

    apiVersion: v1
    kind: List
    items:
    - apiVersion: v1
      kind: Namespace
      metadata:
        name: petstore

    - kind: PersistentVolume
      apiVersion: v1
      metadata:
        name: postgres-pv-volume
        namespace: petstore
        labels:
          type: local
      spec:
        storageClassName: gp2
        capacity:
          storage: 20Gi
        accessModes:
          - ReadWriteMany
        hostPath:
          path: "/mnt/data"

    - apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: postgres-pv-claim
        namespace: petstore
      spec:
        storageClassName: gp2
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 20Gi

    - apiVersion: v1
      kind: Service
      metadata:
        name: postgres
        namespace: petstore
      spec:
        ports:
        - port: 5432
        selector:
          app: postgres
        clusterIP: None

    - apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: postgres
        namespace: petstore
      spec:
        selector:
          matchLabels:
            app: postgres
        strategy:
          type: Recreate
        template:
          metadata:
            labels:
              app: postgres
          spec:
            containers:
            - image: <YourAccountID>.dkr.ecr.us-west-2.amazonaws.com/<UserName>-petstore_postgres:latest
              name: postgres
              env:
              - name: POSTGRES_PASSWORD
                value: password
              - name: POSTGRES_DB
                value: petstore
              - name: POSTGRES_USER
                value: admin
              ports:
              - containerPort: 5432
                name: postgres
              volumeMounts:
              - name: postgres-persistent-storage
                mountPath: /var/lib/postgresql/data
                subPath: petstore
            volumes:
            - name: postgres-persistent-storage
              persistentVolumeClaim:
                claimName: postgres-pv-claim

    - apiVersion: v1
      kind: Service
      metadata:
        name: frontend
        namespace: petstore
      spec:
        selector:
          app: frontend
        ports:
        - port: 80
          targetPort: http-server
          name: http
        - port: 9990
          targetPort: wildfly-cord
          name: wildfly-cord
        type: LoadBalancer

    - apiVersion: apps/v1beta1
      kind: Deployment
      metadata:
        name: frontend
        namespace: petstore
        labels:
          app: frontend
      spec:
        replicas: 2
        selector:
          matchLabels:
            app: frontend
        template:
          metadata:
            labels:
              app: frontend
          spec:
            initContainers:
            - name: init-frontend
              image: <YourAccountID>.dkr.ecr.us-west-2.amazonaws.com/<UserName>-petstore_postgres:latest
              command: ['sh', '-c',
                        'until pg_isready -h postgres.petstore.svc -p 5432;
                        do echo waiting for database; sleep 2; done;']
            containers:
            - name: frontend
              image: <YourAccountID>.dkr.ecr.us-west-2.amazonaws.com/<UserName>-petstore_frontend:latest
              resources:
                requests:
                  memory: "512m"
                  cpu: "512m"
              ports:
              - name: http-server
                containerPort: 8080
              - name: wildfly-cord
                containerPort: 9990
              env:
              - name: DB_URL
                value: "jdbc:postgresql://postgres.petstore.svc:5432/petstore?ApplicationName=applicationPetstore"
              - name: DB_HOST
                value: postgres.petstore.svc
              - name: DB_PORT
                value: "5432"
              - name: DB_NAME
                value: petstore
              - name: DB_USER
                value: admin
              - name: DB_PASS
                value: password

> **Note**
>
> Amazon EKS clusters that were created prior to Kubernetes version 1.11
> were not created with any storage classes. Since we are running the
> version `1.12`, the default `StorageClass` has already been set to
> [Amazon Elastic Block Store (EBS)](https://aws.amazon.com/ebs/).
> Therefore there is no `StorageClass` definition int he
> `petstore-eks-manifest.yaml` file.

Step 2  
Close the `petstore-eks-manifest.yaml`. Run the following commands in
the Cloud9 IDE `terminal` to replace the **&lt;YourAccountID&gt;** as
well as **&lt;UserName&gt;** placeholders in the manifest file, with
your AWS Account ID and unique AWS IAM User.

    ACCOUNT_ID=$(aws sts get-caller-identity --output text --query 'Account')

    sed -i "s/<YourAccountID>/${ACCOUNT_ID}/" petstore-eks-manifest.yaml

    sed -i "s/<UserName>/${USER_NAME}/" petstore-eks-manifest.yaml

Step 3  
Apply your manifest by running this command in your Cloud9 IDE
`terminal`:

    kubectl apply -f petstore-eks-manifest.yaml

Expected Output:

    namespace/petstore created
    persistentvolume/postgres-pv-volume configured
    persistentvolumeclaim/postgres-pv-claim created
    service/postgres created
    deployment.apps/postgres created
    service/frontend created
    deployment.apps/frontend created

As you can see above this manifest created and configured several
components in your Kubernetes cluster, we’ve created a **namespace**,
**persistentvolume**, **persistentvolumeclaim**, 2 **services**, and 2
**deployments**.

<table>
<colgroup>
<col style="width: 50%" />
<col style="width: 50%" />
</colgroup>
<thead>
<tr class="header">
<th>Primitive</th>
<th>Description</th>
</tr>
</thead>
<tbody>
<tr class="odd">
<td><p><strong>Namespace</strong></p></td>
<td><p>Namespaces are meant to be virtual clusters within a larger physical cluster.</p></td>
</tr>
<tr class="even">
<td><p><strong>PersistentValue</strong></p></td>
<td><p>Persistent Volume (PV) is a piece of storage that has been provisioned by an administrator. <em>These are cluster wide resources.</em></p></td>
</tr>
<tr class="odd">
<td><p><strong>PersistentVolumeClaim</strong></p></td>
<td><p>Persistent Volume Claim (PVC) is a request for storage by a user.</p></td>
</tr>
<tr class="even">
<td><p><strong>Service</strong></p></td>
<td><p>Service is an abstraction which defines a logical set of Pods and a policy by which to access them.</p></td>
</tr>
<tr class="odd">
<td><p><strong>Deployment</strong></p></td>
<td><p>Deployment controller provides declarative updates for Pods and ReplicaSets.</p></td>
</tr>
</tbody>
</table>

Step 4  
Now that the scheduler knows that you want to run this application, it
will find available **disk**, **cpu** and **memory** and will place the
pods on **Worker Nodes**. Let’s watch as they get provisioned.

    kubectl get pods --namespace petstore --watch

Example Output:

    NAME                        READY     STATUS              RESTARTS   AGE
    frontend-869db5db6b-ht4h8   0/1       Init:0/1            0          3m
    frontend-869db5db6b-j5nfj   0/1       Init:0/1            0          3m
    postgres-678864b7-vs5zj     0/1       ContainerCreating   5          3m

Step 5  
Once the **STATUS** changes to **Running** for all 3 of your containers
we can then load the services and navigate to the exposed application
(you will need to `[ctrl + c]` since its watching).

    kubectl get services --namespace petstore -o wide

Example Output:

    NAME       TYPE           CLUSTER-IP      EXTERNAL-IP                                                               PORT(S)                                     AGE
    frontend   LoadBalancer   10.100.20.251   ac7059d97a51611e88f630213e88d018-2093299179.us-west-2.elb.amazonaws.com   80:30327/TCP,443:32177/TCP,9990:30543/TCP   6m
    postgres   ClusterIP      None            <none>                                                                    5432/TCP                                    6m

Step 6  
Here we can see that we’re exposing the **frontend** using an ELB, which
is available at the **EXTERNAL-IP** field. Copy and paste this into a
new browser tab. You should see the following web application:

![Preview](../../images/preview.png)

Now that we have our containers deployed to Amazon EKS we can continue
with the workshop and look at how to monitor the **Pet Store**
application.
