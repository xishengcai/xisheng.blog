# [Validating Kubernetes YAML for best practice and policies](https://learnk8s.io/validating-kubernetes-yaml)

https://learnk8s.io/validating-kubernetes-yaml

**TL;DR:** *The article compares six static tools to validate and score Kubernetes YAML files for best practices and compliance.*

Kubernetes workloads are most commonly defined as YAML formatted documents.

One of the challenges with YAML is that it's rather hard to express constraints or relationships between manifest files.

**What if you wish to check that all images deployed into the cluster are pulled from a trusted registry?**

**How can you prevent Deployments that don't have PodDisruptionBudgets from being submitted to the cluster?**

Integrating static checking allows catching errors and policy violations closer to the development lifecycle.

And since the guarantee around the validity and safety of the resource definitions is improved, you can trust that production workloads are following best practices.

The ecosystem of static checking of Kubernetes YAML files can be grouped in the following categories:

- **API validators** — Tools in this category validate a given YAML manifest against the Kubernetes API server.
- **Built-in checkers** — Tools in this category bundle opinionated checks for security, best practices, etc.
- **Custom validators** — Tools in this category allow writing custom checks in several languages such as Rego and Javascript.

In this article, you will learn and compare six different tools:

1. [Kubeval](https://learnk8s.io/validating-kubernetes-yaml#kubeval)
2. [Kube-score](https://learnk8s.io/validating-kubernetes-yaml#kube-score)
3. [Config-lint](https://learnk8s.io/validating-kubernetes-yaml#config-lint)
4. [Copper](https://learnk8s.io/validating-kubernetes-yaml#copper)
5. [Conftest](https://learnk8s.io/validating-kubernetes-yaml#conftest)
6. [Polaris](https://learnk8s.io/validating-kubernetes-yaml#polaris)

Let's get started!



## Validating a deployment

Before you start comparing tools, you should set a baseline.

The following manifest has a few issues and isn't following best practices — *how many can you spot?*

base-valid.yaml

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: http-echo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: http-echo
  template:
    metadata:
      labels:
        app: http-echo
    spec:
      containers:
      - name: http-echo
        image: hashicorp/http-echo
        args: ["-text", "hello-world"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: http-echo
spec:
  ports:
  - port: 5678
    protocol: TCP
    targetPort: 5678
  selector:
    app: http-echo
```

You will be using this YAML file to compare the different tools.

> You can find the above YAML manifest as the file `base-valid.yaml` along with the other manifests referred to in the article in this [git repository](https://github.com/amitsaha/kubernetes-static-checkers-demo).

The manifest describes a web application that always replies with a "Hello World" message on port 5678.

You can deploy the application with:

bash

```
kubectl apply -f hello-world.yaml
```

You can test it with:

bash

```
kubectl port-forward svc/http-echo 8080:5678
```

You can visit [http://localhost:8080](http://localhost:8080/) and confirm that the app works as expected.

*But does it follow best practices?*

**Let's start.**

## Kubeval

The premise of [kubeval](https://www.kubeval.com/) is that any interaction with Kubernetes goes via its REST API.

Hence, you can use the API schema to validate whether a given YAML input conforms to the schema.

*Let's have a look at an example.*

You can follow the [instructions on the project website](https://www.kubeval.com/installation/) to install kubeval.

> As of this writing, the latest release is 0.15.0.

Once installed, let's run it with the manifest discussed earlier:

bash

```
kubeval base-valid.yaml
PASS - base-valid.yaml contains a valid Deployment (http-echo)
PASS - base-valid.yaml contains a valid Service (http-echo)
```

When successful, kubeval exits with an exit code of `0`.

You can verify the exit code with:

bash

```
echo $?
0
```

Let's now try kubeval with another manifest:

kubeval-invalid.yaml

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: http-echo
spec:
  replicas: 2
  template:
    metadata:
      labels:
        app: http-echo
    spec:
      containers:
      - name: http-echo
        image: hashicorp/http-echo
        args: ["-text", "hello-world"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: http-echo
spec:
  ports:
  - port: 5678
    protocol: TCP
    targetPort: 5678
  selector:
    app: http-echo
```

*Can you spot the issue?*

Let's run kubeval:

bash

```
kubeval kubeval-invalid.yaml
WARN - kubeval-invalid.yaml contains an invalid Deployment (http-echo) - selector: selector is required
PASS - kubeval-invalid.yaml contains a valid Service (http-echo)

# let's check the return value
echo $?
1
```

The resource doesn't pass the validation.

Deployments using the `app/v1` API version have to include a selector that matches the Pod label.

The above manifest doesn't include the selector and running kubeval against the manifest reported an error and a non-zero exit code.

*You may wonder what happens when you run `kubectl apply -f` with the above manifest?*

Let's try:

bash

```
kubectl apply -f kubeval-invalid.yaml
error: error validating "kubeval-invalid.yaml": error validating data: ValidationError(Deployment.spec):
missing required field "selector" in io.k8s.api.apps.v1.DeploymentSpec; if you choose to ignore these errors,
turn validation off with --validate=false
```

Exactly the error that kubeval warned you about.

You can fix the resource by adding the selector like this:

base-valid.yaml

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: http-echo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: http-echo
  template:
    metadata:
      labels:
        app: http-echo
    spec:
      containers:
      - name: http-echo
        image: hashicorp/http-echo
        args: ["-text", "hello-world"]
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: http-echo
spec:
  ports:
  - port: 5678
    protocol: TCP
    targetPort: 5678
  selector:
    app: http-echo
```

**The advantage of a tool like kubeval is that you can catch such errors early in your deployment cycle.**

Also, you don't need access to a cluster to run the checks — they could run offline.

By default, kubeval validates resources against the latest unreleased Kubernetes API schema.

In most cases, however, you might want to run validations against a specific Kubernetes release.

You can test a specific API version using the flag `--kubernetes-version`:

bash

```
kubeval --kubernetes-version 1.16.1 base-valid.yaml
```

Please notice that the release version should be of the form of `Major.Minor.Patch`.

To see the versions available for validating against, check out the [JSON schema on GitHub](https://github.com/instrumenta/kubernetes-json-schema) which kubeval uses to perform its validation.

If you need to run kubeval offline, you can download the schemas and then use the `--schema-location` flag to use a local directory.

In addition to individual YAML files, you can run kubeval against directories as well as standard input.

**You should also know that Kubeval makes it for easy integration with your Continuous Integration pipeline.**

If you want to include the checks before you submit your manifests to the cluster, you will be pleased to know that kubeval supports three output formats:

1. Plain text
2. JSON and
3. Test Anything Protocol (TAP)

And you may be able to use one of the formats to parse the output further to create a custom summary of the results.

**One limitation of kubeval is that it is currently not able to validate against Custom Resource Definitions (CRDs).**

However, [you can tell kubeval to ignore them.](https://kubeval.instrumenta.dev/#crds)

Kubeval is an excellent choice to check and validate resources, but please notice that a resource that passes the test isn't guaranteed to conform to best practices.

As an example, using the latest tag in the container images isn't considered a best practice.

However, Kubeval doesn't report that as an error, and it will validate the YAML without warnings.

*What if you want to score the YAML and catch violations such as the latest tag?*

*How can you check your YAML files against best practices?*

## Kube-score

[Kube-score](https://github.com/zegl/kube-score) analyses YAML manifests and scores them against in-built checks.

These checks are selected based on security recommendations and best practices, such as:

- Running containers as a non-root user.
- Specifying health checks for pods.
- Defining resource requests and limits.

The result of a check can be *OK*, *WARNING*, or *CRITICAL*.

You can try out [kube-score online](https://kube-score.com/) or [you can install it locally](https://github.com/zegl/kube-score#installation).

> As of this writing, the latest release is 1.7.0.

Let's try and run it with the previous manifest `base-valid.yaml`:

bash

```
kube-score score base-valid.yaml
apps/v1/Deployment http-echo
[CRITICAL] Container Image Tag
  · http-echo -> Image with latest tag
      Using a fixed tag is recommended to avoid accidental upgrades
[CRITICAL] Pod NetworkPolicy
  · The pod does not have a matching network policy
      Create a NetworkPolicy that targets this pod
[CRITICAL] Pod Probes
  · Container is missing a readinessProbe
      A readinessProbe should be used to indicate when the service is ready to receive traffic.
      Without it, the Pod is risking to receive traffic before it has booted. It is also used during
      rollouts, and can prevent downtime if a new version of the application is failing.
      More information: https://github.com/zegl/kube-score/blob/master/README_PROBES.md
[CRITICAL] Container Security Context
  · http-echo -> Container has no configured security context
      Set securityContext to run the container in a more secure context.
[CRITICAL] Container Resources
  · http-echo -> CPU limit is not set
      Resource limits are recommended to avoid resource DDOS. Set resources.limits.cpu
  · http-echo -> Memory limit is not set
      Resource limits are recommended to avoid resource DDOS. Set resources.limits.memory
  · http-echo -> CPU request is not set
      Resource requests are recommended to make sure that the application can start and run without
      crashing. Set resources.requests.cpu
  · http-echo -> Memory request is not set
      Resource requests are recommended to make sure that the application can start and run without crashing.
      Set resources.requests.memory
[CRITICAL] Deployment has PodDisruptionBudget
  · No matching PodDisruptionBudget was found
      It is recommended to define a PodDisruptionBudget to avoid unexpected downtime during Kubernetes
      maintenance operations, such as when draining a node.
[WARNING] Deployment has host PodAntiAffinity
  · Deployment does not have a host podAntiAffinity set
      It is recommended to set a podAntiAffinity that stops multiple pods from a deployment from
      being scheduled on the same node. This increases availability in case the node becomes unavailable.
```

The YAML file passes the kubeval checks, but `kube-score` points out several deficiencies:

- Missing readiness probes.
- Missing memory and CPU requests and limits.
- Missing Pod disruption budgets.
- Missing anti-affinity rules to maximise availability.
- The container runs as root.

**Those are all valid points that you should address to make your deployment more robust and reliable.**

The `kube-score` command prints a human-friendly output containing all the *WARNING* and *CRITICAL* violations, which is great during development.

If you plan to use it as part of your Continuous Integration pipeline, you can use a more concise output with the flag `--output-format ci` which also prints the checks with level *OK*:

bash

```
kube-score score base-valid.yaml --output-format ci
[OK] http-echo apps/v1/Deployment
[OK] http-echo apps/v1/Deployment
[CRITICAL] http-echo apps/v1/Deployment: (http-echo) CPU limit is not set
[CRITICAL] http-echo apps/v1/Deployment: (http-echo) Memory limit is not set
[CRITICAL] http-echo apps/v1/Deployment: (http-echo) CPU request is not set
[CRITICAL] http-echo apps/v1/Deployment: (http-echo) Memory request is not set
[CRITICAL] http-echo apps/v1/Deployment: (http-echo) Image with latest tag
[OK] http-echo apps/v1/Deployment
[CRITICAL] http-echo apps/v1/Deployment: The pod does not have a matching network policy
[CRITICAL] http-echo apps/v1/Deployment: Container is missing a readinessProbe
[CRITICAL] http-echo apps/v1/Deployment: (http-echo) Container has no configured security context
[CRITICAL] http-echo apps/v1/Deployment: No matching PodDisruptionBudget was found
[WARNING] http-echo apps/v1/Deployment: Deployment does not have a host podAntiAffinity set
[OK] http-echo v1/Service
[OK] http-echo v1/Service
[OK] http-echo v1/Service
[OK] http-echo v1/Service
```

Similar to kubeval, `kube-score` returns a non-zero exit code when there is a *CRITICAL* check that failed, but you configured it to fail even on *WARNINGs*.

There is also a built-in check to validate resources against different API versions — similar to kubeval.

However, this information is hardcoded in kube-score itself, and you can't select a different Kubernetes version.

Hence, if you upgrade your cluster or you have several different clusters running different versions, this can prove to be a severe limitation.

> Please notice that [there is an open issue to implement this feature.](https://github.com/zegl/kube-score/issues/63)

You can learn more about [kube-score on the official website](https://github.com/zegl/kube-score).

*Kube-score checks are an excellent tool to enforce best practices, but what if you want to customise one, or add your own rules?*

You can't.

**Kube-score isn't designed to be extendable and you can't add or tweak policies.**

If you want to write custom checks to comply with your organisational policies, you can use one of the next four options - config-lint, copper, conftest or polaris.

## Config-lint

Config-lint is a tool designed to validate configuration files written in YAML, JSON, Terraform, CSV, and Kubernetes manifests.

You can install it using the [instructions](https://stelligent.github.io/config-lint/#/install) on the project website.

> The latest release is 1.5.0 at the time of this writing.

**Config-lint comes with no in-built checks for Kubernetes manifests.**

You have to write your own rules to perform any validations.

The rules are written as YAML files, referred to as rulesets and have the following structure:

rule.yaml

```
version: 1
description: Rules for Kubernetes spec files
type: Kubernetes
files:
  - "*.yaml"
rules:
   # list of rules
```

Let's have a look in more detail:

- The `type` field indicates what type of configuration you will be checking with `config-lint` — *it is always `Kubernetes` for Kubernetes manifests.*
- The `files` field accepts a directory as input in addition to individual files.
- The `rules` field is where you can define custom checks.

Let's say you wish to check whether the images in a Deployment are always pulled from a trusted repository such as `my-company.com/myapp:1.0`.

A `config-lint` rule implementing such a check could look like this:

rule-trusted-repo.yaml

```
- id: MY_DEPLOYMENT_IMAGE_TAG
  severity: FAILURE
  message: Deployment must use a valid image tag
  resource: Deployment
  assertions:
    - every:
        key: spec.template.spec.containers
        expressions:
          - key: image
            op: starts-with
            value: "my-company.com/"
```

Each rule must have the following attributes:

- `id` — This uniquely identifies the rule.
- `severity` — It has to be one of *FAILURE*, *WARNING*, and *NON_COMPLIANT*.
- `message` — If a rule is violated, the contents of this string is shown.
- `resource` — The kind of resource you want this rule to be applied to.
- `assertions` — A list of conditions that will be evaluated against the specified resource.

In the above rule, the [`every` assertion](https://stelligent.github.io/config-lint/#/operations?id=every) checks that each container in a Deployment (`key: spec.templates.spec.containers`) uses a trusted image (i.e. the image starts with `"my-company.com/"`).

The complete ruleset looks like this:

ruleset.yaml

```
version: 1
description: Rules for Kubernetes spec files
type: Kubernetes
files:
  - "*.yaml"
rules:
  - id: DEPLOYMENT_IMAGE_REPOSITORY
    severity: FAILURE
    message: Deployment must use a valid image repository
    resource: Deployment
    assertions:
      - every:
          key: spec.template.spec.containers
          expressions:
            - key: image
              op: starts-with
              value: "my-company.com/"
```

If you want to test the check, you can save the ruleset as `check_image_repo.yaml`.

Let's now run the validation against the `base-valid.yaml` file:

bash

```
config-lint -rules check_image_repo.yaml base-valid.yaml
[
  {
  "AssertionMessage": "Every expression fails: And expression fails: image does not start with my-company.com/",
  "Category": "",
  "CreatedAt": "2020-06-04T01:29:25Z",
  "Filename": "test-data/base-valid.yaml",
  "LineNumber": 0,
  "ResourceID": "http-echo",
  "ResourceType": "Deployment",
  "RuleID": "DEPLOYMENT_IMAGE_REPOSITORY",
  "RuleMessage": "Deployment must use a valid image repository",
  "Status": "FAILURE"
  }
]
```

**It fails.**

Now, let's consider the following manifest with a valid image repository:

image-valid-mycompany.yaml

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: http-echo
spec:
  replicas: 2
  selector:
    matchLabels:
      app: http-echo
  template:
    metadata:
      labels:
        app: http-echo
    spec:
      containers:
      - name: http-echo
        image: my-company.com/http-echo:1.0
        args: ["-text", "hello-world"]
        ports:
        - containerPort: 5678
```

Run the same check with the above manifest and there will be no violations reported:

bash

```
config-lint -rules check_image_repo.yaml image-valid-mycompany.yaml
[]
```

Config-lint is a promising framework that lets you write custom checks for Kubernetes YAML manifests using a YAML DSL.

*But what if you want to express more complex logic and checks?*

*Isn't YAML too limiting for that?*

*What if you could express those checks with a real programming language?*

## Copper

[Copper V2](https://github.com/cloud66-oss/copper) is a framework that validates manifests using custom checks — just like config-lint.

However, Copper doesn't use YAML to define the checks.

**Instead, tests are written in JavaScript and Copper provides a library with a few basic helpers to assist in reading Kubernetes objects and reporting errors.**

You can follow [the official documentation to install Copper](https://github.com/cloud66-oss/copper#installation).

> The latest release at the time of this writing is 2.0.1.

Similar to `config-lint`, Copper has no built-in checks.

Let's write a check to make sure that deployments can pull container images only from a trusted repository such as `my-company.com`.

Create a new file, `check_image_repo.js` with the following content:

check_image_repo.js

```
$$.forEach(function($){
    if ($.kind === 'Deployment') {
        $.spec.template.spec.containers.forEach(function(container) {
            var image = new DockerImage(container.image);
            if (image.registry.lastIndexOf('my-company.com/') != 0) {
                errors.add_error('no_company_repo',"Image " + $.metadata.name + " is not from my-company.com repo", 1)
            }
        });
    }
});
```

Now, to run this check against our `base-valid.yaml` manifest, you can use the `copper validate` command:

bash

```
copper validate --in=base-valid.yaml --validator=check_image_tag.js
Check no_company_repo failed with severity 1 due to Image http-echo is not from my-company.com repo
Validation failed
```

As you can imagine, you can write more sophisticated checks such as validating domain names for Ingress manifests or reject any Pod that runs as privileged.

Copper has a few built-in helpers:

- The

   

  ```
  DockerImage
  ```

   

  function reads the specified input file and creates an object containing the following attributes:

  - `name` containing the image name
  - `tag` containing the image tag
  - `registry` containing the image registry
  - `registry_url` containing the protocol and the image registry, and
  - `fqin` representing the entire fully qualified image location.

- The `findByName` function helps find a resource given a `kind` and `name` from an input file

- The `findByLabels` function helps find a resource provided `kind` and the `labels`.

You can see [all available helpers here](https://github.com/cloud66-oss/copper/tree/master/libjs).

By default, it loads the entire input YAML file into the `$$` variable and makes it available in your scripts (if you used jQuery in the past, you might find this pattern familiar).

In addition to not having to learn a custom language, you have access to the entire JavaScript language for writing your checks such as string interpolation, functions, etc.

*It is worth noting that the current copper release embeds the ES5 version of the JavaScript engine and not ES6.*

To learn more, you can [visit the official project website](https://github.com/cloud66-oss/copper).

If Javascript isn't your preferred language and you prefer a language designed to query and describe policies, you should check out conftest.

## Conftest

Conftest is a testing framework for configuration data that can be used to check and verify Kubernetes manifests.

Tests are written using the purpose-built query language, [Rego](https://www.openpolicyagent.org/docs/latest/policy-language/).

You can install conftest following the [instructions on the project website.](https://www.conftest.dev/install/)

> At the time of writing, the latest release is 0.18.2.

**Similar to config-lint and copper, conftest doesn't come with any in-built checks.**

So let's try it out, by writing a policy.

As for the previous example, you will check that the container is coming from a trusted source.

Create a new directory, `conftest-checks` and a file named `check_image_registry.rego` with the following content:

check_image_registry.rego

```
package main

deny[msg] {

  input.kind == "Deployment"
  image := input.spec.template.spec.containers[_].image
  not startswith(image, "my-company.com/")
  msg := sprintf("image '%v' doesn't come from my-company.com repository", [image])
}
```

Let's now run conftest to validate the manifest `base-valid.yaml`:

bash

```
conftest test --policy ./conftest-checks base-valid.yaml
FAIL - base-valid.yaml - image 'hashicorp/http-echo' doesn't come from my-company.com repository
1 tests, 1 passed, 0 warnings, 1 failure
```

*Of course, it fails since the image isn't trusted.*

The above Rego file specifies a `deny` block which evaluates to a violation when true.

When you have more than one `deny` block, conftest checks them independently, and the overall result is a violation of any of the blocks results in a breach.

Other than the default output format, conftest supports JSON, TAP, and a table format via the `--output` flag, which is excellent if you wish to integrate the reports with your existing Continuous Integration pipeline.

To help debug policies, conftest has a convenient `--trace` flag which prints a trace of how conftest is parsing the specified policy files.

Conftest policies can be published and shared as artefacts in OCI (Open Container Initiative) registries.

The commands, `push` and `pull` allow publishing an artefact and pulling an existing artefact from a remote registry.

Let's see a demo of publishing the above policy to a local docker registry using `conftest push`.

Start a local docker registry using:

bash

```
docker run -it --rm -p 5000:5000 registry
```

From another terminal, navigate to the `conftest-checks` directory created above and run the following command:

bash

```
conftest push 127.0.0.1:5000/amitsaha/opa-bundle-example:latest
```

The command should complete successfully with the following message:

bash

```
2020/06/10 14:25:43 pushed bundle with digest: sha256:e9765f201364c1a8a182ca637bc88201db3417bacc091e7ef8211f6c2fd2609c
```

Now, create a temporary directory and run the `conftest pull` command which will download the above bundle to the temporary directory:

bash

```
cd $(mktemp -d)
conftest pull 127.0.0.1:5000/amitsaha/opa-bundle-example:latest
```

You will see that there is a new sub-directory `policy` in the temporary directory containing the policy file pushed earlier:

bash

```
tree
.
└── policy
  └── check_image_registry.rego
```

You can even run the tests directly from the repository:

bash

```
conftest test --update 127.0.0.1:5000/amitsaha/opa-bundle-example:latest base-valid.yaml
..
FAIL - base-valid.yaml - image 'hashicorp/http-echo' doesn't come from my-company.com repository
2 tests, 1 passed, 0 warnings, 1 failure
```

*Unfortunately, DockerHub is not yet one of the supported registries.*

However, if you are using [Azure Container Registry (ACR)](https://azure.microsoft.com/en-us/services/container-registry/) or running your container registry, you might be in luck.

The [artefact format is the same as used by Open Policy Agent (OPA) bundles](https://www.openpolicyagent.org/docs/latest/bundles), which makes it possible to use conftest to run tests from existing OPA bundles.

You can find out more about [sharing policies and other features of conftest on the official website](https://www.conftest.dev/).

## Polaris

The last tool you will explore in this article is `polaris` ([https://github.com/FairwindsOps/polaris](https://github.com/FairwindsOps/polaris#cli)).

**Polaris can be either installed inside a cluster or as a command-line tool to analyse Kubernetes manifests statically.**

When running as a command-line tool, it includes several built-in checks covering areas such as security and best practices — similar to kube-score.

Also, you can use it to write custom checks similar to config-lint, copper, and conftest.

In other words, polaris combines the best of the two categories: built-in and custom checkers.

You can install the polaris command-line tool as per the [instructions on the project website](https://github.com/FairwindsOps/polaris/blob/master/docs/usage.md#cli).

> The latest release at the time of writing is 1.0.3.

Once installed, you can run `polaris` against the `base-valid.yaml` manifest with:

bash

```
polaris audit --audit-path base-valid.yaml
```

The above command will print a JSON formatted string detailing the checks that were run and the result of each test.

The output will have the following structure:

output.json

```
{
  "PolarisOutputVersion": "1.0",
  "AuditTime": "0001-01-01T00:00:00Z",
  "SourceType": "Path",
  "SourceName": "test-data/base-valid.yaml",
  "DisplayName": "test-data/base-valid.yaml",
  "ClusterInfo": {
    "Version": "unknown",
    "Nodes": 0,
    "Pods": 2,
    "Namespaces": 0,
    "Controllers": 2
  },
  "Results": [
    /* long list */
  ]
}
```

> [The complete output is available here](https://github.com/amitsaha/kubernetes-static-checkers-demo/blob/master/base-valid-polaris-result.json).

Similar to kube-score, polaris identifies several cases where the manifest falls short of recommended best practices which include:

- Missing health checks for the pods.
- Container images don't have a tag specified.
- The container runs as root.
- CPU and memory requests and limits are not set.

Each check is either classified with a severity level of *warning* or *danger*.

To learn more about the current in-built checks, refer to the [documentation](https://github.com/FairwindsOps/polaris/blob/master/docs/usage.md#checks).

If you are not interested in the detailed results, passing the flag `--format score` prints a number in the range 1-100 which polaris refers to as the *score:*

bash

```
polaris audit --audit-path test-data/base-valid.yaml --format score
68
```

**The closer the score is to 100, the higher the degree of conformance.**

If you inspect the exit code of the `polaris audit` command, you will see that it was `0`.

To make `polaris audit` exit with a non-zero code, you can make use of two other flags.

The `--set-exit-code-below-score` flag accepts a threshold score in the range 1-100 and will exit with an exit code of 4 when the score is below the threshold.

This is very useful in cases where your baseline score is 75, and you want to be alerted when it goes lower.

The `--set-exit-code-on-danger` flag will exit with an exit code of 3 when any of the *danger* checks fail.

*Let's now see how you can define a custom check for `polaris` to test whether the container image in a Deployment is from a trusted registry.*

Custom checks are defined in a YAML format with the test itself described using JSON Schema.

The following YAML snippet defines a new check-called `checkImageRepo`:

snippet.yaml

```
checkImageRepo:
  successMessage: Image registry is valid
  failureMessage: Image registry is not valid
  category: Images
  target: Container
  schema:
    '$schema': http://json-schema.org/draft-07/schema
    type: object
    properties:
      image:
        type: string
        pattern: ^my-company.com/.+$
```

Let's have a closer look at it:

- `successMessage` is a string which will be displayed when the check succeeds.
- `failureMessage` is displayed when the test is unsuccessful.
- `category` refers to one of the categories - `Images`, `Health Checks`, `Security`, `Networking` and `Resources`.
- `target` is a string that determines which *spec* object the check is applied against - and should be one of `Container`, `Pod`, or `Controller`.
- The test itself is defined in the `schema` object using JSON schema. Here the check uses the `pattern` keyword to match whether the image is from an allowed registry or not.

To run the check defined above you will need to create a Polaris configuration file as follows:

polaris-conf.yaml

```
checks:
  checkImageRepo: danger
customChecks:
  checkImageRepo:
    successMessage: Image registry is valid
    failureMessage: Image registry is not valid
    category: Images
    target: Container
    schema:
      '$schema': http://json-schema.org/draft-07/schema
      type: object
      properties:
        image:
          type: string
          pattern: ^my-company.com/.+$
```

Let's break down the file:

- The `checks` field specifies the checks and their severity. Since you want to be alerted when the image isn't trusted, `checkImageRepo` is assigned a `danger` severity level.
- The `checkImageRepo` check itself is then defined in the `customChecks` object.

You can save the above file as `custom_check.yaml` and run `polaris audit` with the YAML manifest that you wish to validate.

You can test it with the `base-valid.yaml` manifest:

bash

```
polaris audit --config custom_check.yaml --audit-path base-valid.yaml
```

You will see that `polaris audit` ran only the custom check defined above, which did not succeed.

If you amend the container image to `my-company.com/http-echo:1.0`, `polaris` will report success.

> [The Github repository contains the amended manifest](https://github.com/amitsaha/kubernetes-static-checkers-demo), so you can test the previous command against the `image-valid-mycompany.yaml` manifest.

*But how do you run both the built-in and custom checks?*

The configuration file above should be updated with all the built-in check identifiers and should look as follows:

config_with_custom_check.yaml

```
checks:
  cpuRequestsMissing: warning
  cpuLimitsMissing: warning
  # Other inbuilt checks..
  # ..
  # custom checks
  checkImageRepo: danger
customChecks:
  checkImageRepo:
    successMessage: Image registry is valid
    failureMessage: Image registry is not valid
    category: Images
    target: Container
    schema:
      '$schema': http://json-schema.org/draft-07/schema
      type: object
      properties:
        image:
          type: string
          pattern: ^my-company.com/.+$
```

> You can see [an example of a complete configuration file here](https://github.com/amitsaha/kubernetes-static-checkers-demo/blob/master/polaris-configs/config_with_custom_check.yaml).

You can test the `base-valid.yaml` manifest with custom and built-in checks with:

bash

```
polaris audit --config config_with_custom_check.yaml --audit-path base-valid.yaml
```

Polaris augments the built-in checks with your custom checks, thus combining the best of both worlds.

However, not having access to more powerful languages like Rego or JavaScript may be a limitation to write more sophisticated checks.

To learn more about polaris, check out the [project website](https://github.com/FairwindsOps/polaris).

## Summary

While there are plenty of tools to validate, score and lint Kubernetes YAML files, **it's important to have a mental model on how you will design and perform the checks.**

As an example, if you were to think about Kubernetes manifests going through a pipeline, **kubeval could be the first step in such a pipeline as it validates if the object definitions conform to the Kubernetes API schema.**

Once this check is successful, perhaps you could pass on to more elaborated tests such as standard best practices and custom policies.

Kube-score and polaris are to excellent choices here.

If you have **complex requirements and want to customise the checks down to the details, you should consider copper, config-lint, and conftest.**

While both conftest and config-lint use more YAML to define custom validation rules, copper gives you access to a real programming language making it quite attractive.

*But should you use one of these and write all the checks from scratch or should you instead use Polaris and write only the additional custom checks?*

**It depends.**

The following table presents a summary of the tools:

| Tool        | Features                                                     | Limitations                                                  | Custom checks |
| ----------- | ------------------------------------------------------------ | ------------------------------------------------------------ | ------------- |
| kubeval     | Validate YAML manifests against API Schema of a specific version | Doesn't recognise CRDs                                       | No            |
| kube-score  | Analyses YAML manifests against standard best practices Deprecated API version check | Doesn't validate the definition No support for specific API versions for deprecated resource check | No            |
| copper      | A generic framework for writing custom checks for YAML manifests using JavaScript | No inbuilt checks Sparse documentation                       | Yes           |
| config-lint | A generic framework for writing custom checks using DSL embedded in YAML The framework also supports other configuration formats - Terraform, for example. | No inbuilt tests The inbuilt assertions and operations may not be sufficient to account for all checks | Yes           |
| conftest    | A generic framework for writing custom checks in Rego Rego is a robust policy language Sharing policies via OCI bundles | No inbuilt checks Rego has a learning curve Docker hub not supported for sharing of policies | Yes           |
| polaris     | Analyses YAML manifest against standard best practices Allows writing custom checks using JSON Schema | JSON Schema-based checks may not be sufficient               | Yes           |

Since these tools don't rely on access to a Kubernetes cluster, they are straightforward to set up and enable you to enforce gating as well as give quick feedback to pull request authors for projects.