# VMC from scratch

This project contains scripts to create the distributed pipeline for NLP processing
implemented within the NewsReader project. The pipeline follows an streaming computing architecture,
where the computation is not limited to any timeframe. Instead, the pipeline
is always waiting to the arrival of new documents, and when such new document
arrives the NLP processing starts.

The processing NLP modules and the software infrastructure for performing
parallel and distributed streaming processing of documents is packed into virtual
machines (VM). Specifically, we distinguish two types of VM into the cluster:

* One *boss* node, which is the main entry of the documents and which
supervises the processing.
* Several *worker* nodes, which actually perform the NLP processing.

**Detailed documentation can be found under the /doc folder of this repository
(https://github.com/ixa-ehu/vmc-from-scratch/tree/master/doc)**

Creating a cluster using the scripts involves three main steps:

1. Create a basic cluster with the boss node and one worker node.
2. Make as many copies as required of the worker node.
3. Deploy the worker copies among different hosts and run the cluster.

##Table of Contents

1. [Creating a basic cluster](#creating-a-basic-cluster)
2. [Making copies of the worker node](#making-copies-of-the-worker-node)
3. [Deploying and running the cluster](#deploying-and-running-the-cluster)
4. [Sending documents to process](#sending-documents-to-process)
5. [Defining custom topologies](#defining-custom-topologies)
6. [Detailed documentation](#documentation)


##Creating a basic cluster

The first step is to create the basic cluster using the create_basic_cluster.pl
script. The script is executed as follows:

```bash
% sudo ./create_basic_cluster.pl --boss-ip 192.168.122.111 --boss-name bossvm --worker-ip 192.168.122.112 --worker-name workervm1
```
*Please note that the VM images created by these scripts are huge (9 Gb
memory), as they contain all the NLP modules of the Newsreader processing
pipeline. Likewise, the machine to install those VMs need to have a large amount
of RAM memory, as each VM, particularly the worker nodes, need circa 14Gb
of memory to run.*

The next step is to turn on both VMs and start a synchronization process
so that the required software (both the system software as well as the NLP
modules) is properly installed in the newly created VMs:

```bash
% virsh create nodes/bossvm.xml
% virsh create nodes/workervm1.xml
% ssh newsreader@192.168.122.111
(pass: readNEWS89)
```

*Note: If you get an error when trying to run the VMs, you might have
 to edit the files nodes/bossvm.xml and nodes/workervm1.xml, and set
 value "/usr/bin/qemu-system-x86_64" instead of "/usr/bin/qemu-kvm" in
 /domain/devices/emulator element.*

*Note: Worker VMs need 14GB of memory to run all modules of the
 pipeline. The most efficient solution in this case is to create a
 dedicated machine which only runs the NED module, as this module
 needs circa 9GB of memory, and create as many VMs as needed without
 the NED module and only 5GB of memory. The boss VM does not need more
 memory than 3GB to run, but please note that all VMs (including the
 boss VM) are assigned 14GB by default. Edit the VM's definition XML
 file (nodes/workervmX.xml) to change the assigned amount of memory.*

Once logged into the boss VM, run the following:

```bash
$ sudo /root/init_system.sh -l {en|es}
```

The NLP modules are installed in the boss VM when init_system.sh is called. However, to install them in the worker nodes, run the following in the boss VM:

```bash
$ sudo pdsh -w worker_ip /home/newsreader/update_nlp_components_worker.sh
```


##Making copies of the worker node

The next step is thus to copy the worker VM and create new worker nodes in
the cluster. Before doing this, however, the boss and the worker VMs must be
shut down:

```bash
$ sudo pdsh -w workervm1 poweroff
$ sudo poweroff
```

Once the cluster shut down, one can make as many copies as wanted of the
worker nodes. The script cp_worker.pl accomplishes this task. For instance,
the following command will create two more worker nodes:

```bash
% sudo ./cp_worker.pl --boss-img nodes/bossvm.img --worker-img nodes/workervm1.img 192.168.122.113,workervm2 192.168.122.114,workervm3
```


##Deploying and running the cluster

In principle the worker VMs can be executed in any host machine, as far as the
host has a 64 bit CPU. The main requirement is that the IP of the worker VM,
as specified when creating the VM image, is accessible from within the boss
VM. Likewise, the boss IP has to be accessible from the worker VM.

Apart from the topology definition, running the topology requires knowing
the total number of CPUs used in the cluster (-p parameter of the run_topology.sh script).

For instance, if we were using 6 CPUs in our cluster, we would run the following inside de
boss VM to run the topology:

```bash
$ opt/sbin/run_topology.sh -g 6 -s opt/topologies/specs/test.xml
```

This will load the topology and, as a consequence, the cluster will be ready
to accept and process documents.


##Sending documents to process

It is possible to send documents from inside or outside the cluster VMs.

Run the following command to send a document from inside the boss VM:

```bash
$ opt/sbin/push_queue -f docs/input/input.xml
```

The command to send a document from outside the cluster is as follows:

```bash
% curl --form "file=@input.xml" http://BOSSIP:80/upload_file_to_queue.php
```


##Defining custom topologies:

The topology executed by the cluster is declaratively defined in an XML document.
Here is an excerpt of a small topology:

```xml
<topology>
  <cluster componentsBaseDir="/home/newsreader/components"/>
  <module name="EHU-tok" runPath="EHU-tok/run.sh"
          input="raw" output="text"
          procTime="10"/>
  <module name="EHU-pos" runPath="EHU-pos/run.sh"
          input="text" output="terms"
          procTime="15" source="EHU-tok"/>
  <module name="EHU-nerc" runPath="EHU-nerc/run.sh"
          input="terms" output="entities"
          procTime="75" source="EHU-pos"/>
</topology>
```

The <cluster> element specifies the base directory of the NLP modules. Each
module is described by a <module> element, whose attributes are the following:

* **name** (required): the name of the module.
* **runPath** (required): the path relative to componentsBaseDir where the module resides.
* **input** (required): a comma separated list of NAF layers required by the module as input.
* **output** (required): a comma separated list of NAF layers produced by the module.
* **source** (optional): the previous module in the pipeline. If absent, the attribute will
get the value of the immediately preceding it according to the XML tree. If the module
is the first node in the XML tree, and the source attribute is absent, the attribute gets
no value at all.
* **procTime** (optional): the percentage of time this particular module uses when processing
a document.
* **numExec** (optional): the number of instances of the module that will run in parallel.


##Dedicated VMs

Dedicated VMs are those which only run certain modules of the
pipeline. For instance, we recommend to have a dedicated VM which only
runs the NED module, and assign 10GB to it. Then, the rest of VMs
would not need to run the NED module and would not need more than 5GB.

*Note: run 'sudo supervisorctl stop spotlight' command to stop the NED
  process.*

Follow the steps below to create a dedicated VM:

1. Edit the Storm config file of the VM
(/opt/storm/config/storm.yaml), and add the following lines:

```yaml
supervisor.scheduler.meta:
    vm_type: "WORKER_TYPE"  # Create your own worker types here
```

2. Restart storm-supervisor process running the following command:

```bash
$ sudo supervisorctl restart storm-supervisor
```

3. In topology spec file
(~/opt/topologies/specs/nwr_v30_nonlinear.xml), set the 'vm_type'
attribute to each module to be run on the dedicated machine. For
instance, in the following topology we are defining that the EHU-ned
module will run on any dedicated VM of type "NEDWorker":

```xml
<topology>
  <cluster componentsBaseDir="/home/newsreader/components"/>
  <module name="EHU-tok" runPath="EHU-tok/run.sh"
          input="raw" output="text"
          procTime="10"/>
  <module name="EHU-pos" runPath="EHU-pos/run.sh"
          input="text" output="terms"
          procTime="15" source="EHU-tok"/>
  <module name="EHU-nerc" runPath="EHU-nerc/run.sh"
          input="terms" output="entities"
          procTime="75" source="EHU-pos"/>
  <module name="EHU-ned" runPath="EHU-ned/run.sh"
          input="entities" output="entities"
          procTime="15" source="EHU-nerc" vm_type="NEDWorker"/>
</topology>
```


##Documentation

Detailed documentation can be found under the /doc folder of this repository
(https://github.com/ixa-ehu/vmc-from-scratch/tree/master/doc)
