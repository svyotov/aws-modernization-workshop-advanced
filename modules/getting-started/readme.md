Getting Started with the Workshop
=================================

**Expected Outcomes:**

-   Configure IDE Environment and Roles.

-   Update installed packages.

-   Install 3<sup>rd</sup> Party applications.

-   Launch EKS Cluster.

**Lab Requirements:** None

**Average Lab Time:** 15-20 minutes

In order for you to successfully complete the workshop, we need you to
run through a few steps to finalize the configuration of your AWS Cloud9
environment. Your AWS Cloud9 environment is accessible from the [AWS
Console](https://us-west-2.console.aws.amazon.com/cloud9/home?region=us-west-2#).
Once you’ve accessed the console, open the
`[red yellow-background]#<User Name>#-AWSModernizationWorkshop-IDEStack`
IDE.

![Ope IDE](../../images/cloud9-launch.png)

Update Unique User Name Settings
--------------------------------

Since the majority of the AWS resources being created will leverage the
**AWS CLI**, we will automatically create a variable to substitute your
unique user name into these commands.

To get started, open a new `terminal` by pressing the combination keys
`[alt + t]` (Windows/Linux) or `[⌥ + t]` (Mac OS). Create a `USER_NAME`
variable by running the following command, substituting your &lt;User
Name&gt; in place of &lt;LOWER CASE UNIQUE USER NAME&gt;.

    export USER_NAME=<LOWER CASE UNIQUE USER NAME>

> **Tip**
>
> For example, if your unique user name is **Bob**, the command will
> look as follows:
>
>     export USER_NAME=bob

Confirm that your &lt;User Name&gt; has been configured correctly.

    echo $USER_NAME

> **Warning**
>
> Confirm that the parameter value is **lower case**!

You will now save this variable so that we can use it throughout the
workshop.

    echo "export USER_NAME=$USER_NAME" >> ~/.bashrc && source ~/.bashrc

Update and install the necessary tools
--------------------------------------

Now update the `AWS CLI` and other pre-installed packages by running the
following command:

    sudo yum update -y && \
    sudo yum install -y jq gettext && \
    pip install --upgrade --user awscli pip && \
    exec $SHELL

After you have the installed the latest `awscli` and `pip` we need to
configure our environment further.

    aws configure set region us-west-2

Update the IAM Instance Profile
-------------------------------

Next we need to turn off the **AWS Managed Temporary credentials** as
the Cloud9 IDE needs to use the assigned IAM Instance profile. Open the
**AWS Cloud9** menu, go to **Preferences**, then go to **AWS Settings**,
and disable **AWS managed temporary credentials**, as depicted in the
diagram below:

![Cloud9 Managed Credentials](../../images/cloud9-credentials.png)

Clone the source repository for this workshop.
----------------------------------------------

Now we want to clone the repository that contains all the content and
files you need to complete this workshop.

    cd ~/environment && \
    git clone https://github.com/darkreapyre/aws-modernization-workshop-advanced.git

Installing 3rd Party CLIs
-------------------------

During the workshop we will be using a couple of 3<sup>rd</sup> party
CLI tools like `eksctl` to configure our EKS cluster, and `kubectl` to
interact with our Kubernetes cluster. Follow the steps below to ensure
that these tools have been installed:

> **Tip**
>
> You can learn more about the `eksctl` tool from this
> [blog](https://aws.amazon.com/blogs/opensource/eksctl-eks-cluster-one-command/)
> post.

Step 1  
Let’s make a `bin` folder where these binaries will be stored and change
our directory to the new location.

    mkdir ~/bin && cd ~/bin

Step 2  
Download the required 3<sup>rd</sup> party `CLI` tools from their
locations and make them "runnable", and add them to our `$PATH`.

    curl -skL "https://github.com/weaveworks/eksctl/releases/download/latest_release/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp && \
    mv /tmp/eksctl ~/bin/

    curl -skLo ~/bin/kubectl "https://amazon-eks.s3-us-west-2.amazonaws.com/1.12.7/2019-03-27/bin/linux/amd64/kubectl"

    curl -skLo ~/bin/aws-iam-authenticator "https://amazon-eks.s3-us-west-2.amazonaws.com/1.12.7/2019-03-27/bin/linux/amd64/aws-iam-authenticator" && \
    chmod -R +x ~/bin && \
    echo "export PATH=~/bin:\${PATH}" >> ~/.bashrc &&\
    exec $SHELL

Launch an EKS Cluster
---------------------

It takes a few minutes to launch an EKS cluster, so we will have you
launch one now, so that the installation can complete while you continue
with the initial modules. We will launch our EKS Cluster using the
`eksctl` tool.

Step 1  
`eksctl` requires an SSH Key to configure your EKS nodes with.

    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

> **Note**
>
> When prompted to enter a passphrase, press \[ENTER\]

Step 2  
Now that we have the key, let’s launch the EKS Cluster. Our **EKS**
cluster will be called `[red yellow-background]#<User Name>#-petstore`
and will consist of the default, four `m5.large` **EC2** instances.

    eksctl create cluster --full-ecr-access --name=${USER_NAME}-petstore --nodes-min=2 --nodes-max=4

You can expect to see an output like the one below…

<!-- -->

    [ℹ]  using region us-west-2
    [ℹ]  setting availability zones to [us-west-2b us-west-2d us-west-2c]
    [ℹ]  subnets for us-west-2b - public:192.168.0.0/19 private:192.168.96.0/19
    [ℹ]  subnets for us-west-2d - public:192.168.32.0/19 private:192.168.128.0/19
    [ℹ]  subnets for us-west-2c - public:192.168.64.0/19 private:192.168.160.0/19
    [ℹ]  nodegroup "ng-c16b6b90" will use "ami-0923e4b35a30a5f53" [AmazonLinux2/1.12]
    [ℹ]  creating EKS cluster "petstore" in "us-west-2" region
    [ℹ]  will create 2 separate CloudFormation stacks for cluster itself and the initial nodegroup
    [ℹ]  if you encounter any issues, check CloudFormation console or try 'eksctl utils describe-stacks --region=us-west-2 --name=petstore'
    [ℹ]  2 sequential tasks: { create cluster control plane "petstore", create nodegroup "ng-c16b6b90" }
    [ℹ]  building cluster stack "eksctl-petstore-cluster"
    [ℹ]  deploying stack "eksctl-petstore-cluster"
    ...

We will leave this process running, and get back to it later in the
workshop. So let’s open a new `terminal` by pressing the combination
keys `[alt + t]` (Windows/Linux) or `[⌥ + t]` (Mac OS). Then we’ll
proceed to the **Containerize Application** module.
