#!/bin/bash

d_binaries () {

        # Download binary and unzip it
        wget https://github.com/scorestack/scorestack/releases/download/v0.8.1/dynamicbeat-v0.8.1.zip

        unzip dynamicbeat-v0.8.1.zip

}


mv_dynamicbeat () {

        # Create  directory in opt for dynamicbeat and move the binary there
        mkdir /opt/dynamicbeat

        mv dynamicbeat /opt/dynamicbeat

        echo "elasticsearch: https://localhost:9200
log:
  level: 0
  no_color: false
  verbose: false
password: changeme
round_time: 30s
setup:
  kibana: https://localhost:5601
  password: changeme
  username: elastic
teams:
- name: team01
  overrides: {}
- name: team02
  overrides: {}
username: dynamicbeat
verify_certs: false" > /opt/dynamicbeat/dynamicbeat.yml

}


change_configs () {

        # Make config changes needed for Scorestack to work correctly
        sudo sysctl -w net.ipv4.ping_group_range="0   2147483647"

        sudo sysctl -w vm.max_map_count=262144

}


install_reqs () {

        # Install required packages
        apt-get update
        apt-get -y install docker
        apt-get -y install docker-compose
        apt-get -y install git
        apt-get -y install curl
        apt-get -y install unzip

}


deploy_dynamicbeat () {

        # If the service file already exists, ask the user if they want to overwrite it.
        if [[ -f /etc/systemd/system/dynamicbeat.service ]];
        then
                read -p "dynamicbeat service file already exists. Would you like to overwrite it? [Y/N]" replace </dev/tty
                echo $replace

                if [[ "${replace}" == "Y" || "${replace}" == "y" ]];
                then
                        echo "[Unit]
Description=Dynamicbeat
After=network.target
[Service]
Type=simple
WorkingDirectory=/opt/dynamicbeat
ExecStart=/opt/dynamicbeat/dynamicbeat run
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/dynamicbeat.service


                else
                        true
                fi
                else
                        echo "[Unit]
Description=Dynamicbeat
After=network.target
[Service]
Type=simple
WorkingDirectory=/opt/dynamicbeat
ExecStart=/opt/dynamicbeat/dynamicbeat run
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/dynamicbeat.service
        fi

}

install_scorestack () {

        # If the scorestack directory doesn't exist then git clone Scorestack
        if [[ ! -f scorestack ]];
        then
                git clone --branch stable https://github.com/scorestack/scorestack.git
        fi

        sudo docker-compose -f scorestack/deployment/small/docker/docker-compose.yml up -d

        # Set Elasticsearch and Kibana up based on dynamicbeat configuration
        /opt/dynamicbeat/dynamicbeat setup --config /opt/dynamicbeat/dynamicbeat.yml

        # Load checks into Elasticsearch via dynamicbeat
        #/opt/dynamicbeat/dynamicbeat setup checks scorestack/examples

        # Start and enable the Dynamicbeat service
        systemctl daemon-reload
        systemctl start dynamicbeat.service
        systemctl enable dynamicbeat.service

}

install_reqs

d_binaries

mv_dynamicbeat

change_configs

deploy_dynamicbeat

install_scorestack
