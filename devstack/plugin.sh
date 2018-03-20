#!/bin/bash

source ./settings



function install_nix() {

    curl https://nixos.org/nix/install | sh    
    nix-channel --add http://84.39.63.212/jobset/opencontrail/trunk/channel/latest contrail
    nix-channel --update

}

function install_contrail_config() {


    nix-env -i contrail-api-server --option extra-binary-caches http://84.39.63.212 --option trusted-public-keys cache.opencontrail.org:OWF7nfkyJEPX4jYvOrcuelFUH4njVRJ6SDM6+xlFUOQ=

    nix-env -i contrail-discovery --option extra-binary-caches http://84.39.63.212 --option trusted-public-keys cache.opencontrail.org:OWF7nfkyJEPX4jYvOrcuelFUH4njVRJ6SDM6+xlFUOQ=

    nix-env -i contrail-query-engine --option extra-binary-caches http://84.39.63.212 --option trusted-public-keys cache.opencontrail.org:OWF7nfkyJEPX4jYvOrcuelFUH4njVRJ6SDM6+xlFUOQ=

    nix-env -i contrail-svc-monitor --option extra-binary-caches http://84.39.63.212 --option trusted-public-keys cache.opencontrail.org:OWF7nfkyJEPX4jYvOrcuelFUH4njVRJ6SDM6+xlFUOQ=

}





# Script Entry point

if [[ "$1" == "stack" && "$2" == "source" ]]; then
    # Called after projects lib are sourced, before packages installation

    # Check to see if we are already running DevStack
    # Note that this may fail if USE_SCREEN=False
    if type -p screen > /dev/null && screen -ls | egrep -q "[0-9]\.$CONTRAIL_SCREEN_NAME"; then
        echo "You are already running a stack.sh session."
        echo "To rejoin this session type 'screen -x stack'."
        echo "To destroy this session, type './unstack.sh'."
        exit 1
    fi
<<COMMENT1
    if _vercmp $CONTRAIL_BRANCH "<" R4.0 && _vercmp $os_RELEASE ">" '14.04'; then
        # Before R4.0, we need irond server which is installed from opencontrail PPA package 'ifmap-server'
        # but it depends on upstart init system which replaced by systemd since 15.04 Ubuntu release.
        #FIXME: convert ifmap-server upstart script to systemd or install upstart (tried and need a reboot?)
        #FIXME: Authorize to use R3.2 without irond as we can use Contrail embeded IFMAP server since patch
        # https://review.opencontrail.org/#/q/Ib35b48b20c8d46005bf18e8f9b81064985099ff7,n,z
        echo "Ubuntu release upper than precice (14.04) does not support "
        echo "Contrail version under R4.0."
        exit 1
    elif _vercmp $os_RELEASE ">" '16.04'; then
        echo "Ubuntu release $os_CODENAME ($os_RELEASE) is not supported by "
        echo "that devstack plugin."
        exit 1
    fi    
COMMENT1

    #####
    #To be updated 




elif [[ "$1" == "stack" && "$2" == "pre-install" ]]; then
    # Called afer pip requirements installation
    install_nix
    install_contrail_config

elif [[ "$1" == "stack" && "$2" == "install" ]]; then
    # Called after services installation
    <<COMMENT1
    if is_service_enabled q-svc; then
        # Build contrail neutron plugin as it isn't handled by scons
        # It should happen after neutron installation, as it depends on neutron
        #FIXME? as contrail neutron plugin misses a setup.cfg, we wan't use setup_develop
        setup_package $CONTRAIL_DEST/openstack/neutron_plugin -e
    fi

    echo_summary "Configuring contrail"

    source $CONTRAIL_PLUGIN_DIR/lib/contrail_config
    # Use bash completion features to conveniently run all config functions
    for config_func in $(compgen -A function contrail_config_); do
        eval $config_func
    done

    # Force vrouter module re-insertion if asked
    [[ "$RELOAD_VROUTER" == "True" ]] && remove_vrouter
    insert_vrouter

COMMENT1
    echo "install"

elif [[ "$1" == "stack" && "$2" == "post-config" ]]; then
    # Called after services configuration

    echo_summary "Starting contrail"
    #FIXME: Contrail api must be started before neutron, this is why it must be done here.
    # But shouldn't neutron plugin reconnect if api is unreacheable?
    start_contrail
fi
