# ConMan (Configuration Management) Script
    
This is simple Configuration Management script enough to configure the debian machines with SSH protocol enabled with configurations with respect 
to packages installation/removal, service state and file ownership, metadata or content management with a YAML based 
configuration or CLI mode.

it uses [yq](https://mikefarah.gitbook.io/yq/#install) tool not the `python-yq` as it's dependency to parse through the YAML config files. 

## Architecture

Simple script file which creates a scripts to be executed for the configurataions of the remote system parsed from yaml or CLI options and then executed in the SSH channel opened for the hosts. 

## Considerations for config file: 

* `.json `- JavaScript Object Notation or JSON is an open-standard file format that uses readable text to transmit data 
objects consisting of attribute–value pairs and array data types 
* `.yaml` -  is a human-readable data serialization language. It is commonly used for configuration files, but could 
be used in many applications where data is being stored or transmitted ( Chosen )

After experimenting, I have choosen `.yaml` over `json`  because I was able to define the config rules of 
hosts in most human friendly format with key:value and array  with clean definitions. Having significant 
experience with `.yaml` configs, I have decided to use it for best interest of time even after spending some time  on `.json`.
Also, `yaml` can be configured to multiple docs with seperator `---` which can extended for future versions. 

## Consuming Pattern:

The configuration presented in the `yaml` files can be done with command line options as well. Configure the `yml` config
and pass it on in the script or Use the Options to utilise for one time usage any script. 


## Docs 

### installation

Clone this [repo](https://github.com/azarudeena/conman) and execute the `Bootstrap.sh` in bin folder script and add the `conman.sh` to PATH (with alias if preferred). or just use it as it is. 

### Usage

``` markdown
    Options:
      -y YAML configuration file path
      -i identity file for ssh configuration
      -u Username for the host
      -h host ips or DNS name, Multiple hosts can also be provide refer below
      -f full path to script file to be executed in the hosts
      -c commands to be executed in the hosts, Ex: 'ps;ls -ltr; df /'
      -I packages to install Ex: vim,apache2
      -R packages to remove Ex: vim,nano
      -s state:service to be maintained service to be the name of the service. state: desired state; Valid values: start, stop, restart, enable, disable Ex: start:apache2
      
      Usage 
        ./conman.sh -y <yaml config path>
        Ex: ./conman.sh -y ./config.yaml 
        
        ./conman.sh -u <username> -h <hostips> -f <path to scriptfile>";
        Ex: ./conman.sh -u alice -h x.x.x.x -f /here/this-file.sh -c 'pwd;ls;'

        For multiple hosts in CLI 
        ./conman.sh -u alice -h x.x.x.x -h x.x.x.x -f /here/this-file.sh
```

### Config file Example 

```yaml
hosts: 
  name : 34.228.38.208,100.26.22.98
  user: root
  package:
    install:
      - name: apache2
      - name: php
      - name: libapache2-mod-php
    remove:
      - name: vim
      - name: nano
  service:
    restart:apache2
  files:
    config:
    - name: azar
      path: /home/ubuntu
      owner: ubuntu
      group: ubuntu
      mode: 0777
      service:
        restart:apache2
    - name: testfile2
      path: /home/ubuntu
      owner: ubuntu
      group: ubuntu
      mode: 0700
    content:
    - name: index.php
      path: /var/www/html
      text: |
        <?php
           echo "Hello World";
        ?>
    - name: info.php
      path: /var/www/html
      text: |
        <?php
          phpinfo();
        ?>
    - name: dir.conf
      path: /etc/apache2/mods-enabled/
      text: |
        <IfModule mod_dir.c>
           DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm
        </IfModule>
```

### Syntax 

The config file needs to be [yaml](http://www.yaml.org/) file.

|     Element   |                                        Description                                        | Mandatory |
|---------------|-------------------------------------------------------------------------------------------|-----------|
|hosts| Defines the hosts configuration like DNS, iPs and usernames to login with in the hose <br>  `name` :  will have the DNS names or IP address or the hosts. can have multiple hosts seperated by commas(,) </br> `user`: user name to be used with  |   true    |
|package| Defines Debian packages to be installed are removed. has two sub sections. <br>`install` : is array of packages to be installed <br> `remove` is array of packages to be removed | false
|service| Defines the system service to set in its desired state. Option can be defined as `<desired state>:<servicename>` eg: `restart:apache2`| false
|files| Defines the file management for the host system with respect to metadata, ownership and content. consists of two sections  seperated for content and ownership/metadata. <br><br> `config`: contains array of file specific ownership and metadata. <br><br> `name`: name of the file <br> `path`: path of the file in the remote system. <br> `owner`: Username to assigned for the file. <br> `group`: usergroup to be assigned for the file. <br> `mode`: permission for the file. <br> <br> <strong> This script won't validate the correctness of the user and group available in the system. User and Group addition can be included for improvement</strong> <br><br> `content` contains the array of elements carrying content of the file. <br><br> `name`: name of the file <br> `path`: path of the file in the remote system. <br> `text`: file content needs to be updated. <br> <br> | false

The `config` as well as `content` array elements can mark a service to set to specific state after the modification. Please refer example. 

### logging

Logs for this tool is configurable the script. just replace `log.out` at the start of the script file to specific file to append the logs. Defaults to log.out in the same location as script.  

### Improvements can be made

1. validation of yaml configuration for valid values. 
2. in the files config section, validation of user or group availble in the remote system to softly fail the progress. 
3. user addition and deletion. 
4. command to execute can be configurable in yaml. 
5. Parsing of multi doc yaml configuration.
6. make the script file to platform based binary with [shc compiler](https://github.com/neurobin/shc)
7. and the list goes on... forever