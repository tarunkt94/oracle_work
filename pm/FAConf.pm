package FAConf;

use strict;

our %vmsinfo = (
    HA => {
        'REL10' => {
            'FA_GSI' => {
                'vms' => '14',
                'mem' => '614912'
            },
            'FA_HCM' => {
                'vms' => '12',
                'mem' => '310784'
            },
            'FA_CRM' => {
                'vms' => '12',
                'mem' => '328192'
            },
        },
        'REL11' => {
            'FA_GSI' => {
                'vms' => '14',
                'mem' => '666112'
            },
            'FA_HCM' => {
                'vms' => '12',
                'mem' => '310784'
            },
            'FA_CRM' => {
                'vms' => '12',
                'mem' => '328192'
            },
        },
        'REL12' => {
            'FA_GSI' => {
                'vms' => '14',
                'mem' => '666112'
            },
            'FA_HCM' => {
                'vms' => '12',
                'mem' => '310784'
            },
            'FA_CRM' => {
                'vms' => '12',
                'mem' => '328192'
            },
        },
    },
    NONHA => {
        'REL10' => {
            'FA_GSI' => {
                'vms' => '12',
                'mem' => '350720'
            },
            'FA_HCM' => {
                'vms' => '9',
                'mem' => '182784'
            },
            'FA_CRM' => {
                'vms' => '9',
                'mem' => '194048'
            },
        },
        'REL11' => {
            'FA_GSI' => {
                'vms' => '12',
                'mem' => '381440'
            },
            'FA_HCM' => {
                'vms' => '9',
                'mem' => '182784'
            },
            'FA_CRM' => {
                'vms' => '9',
                'mem' => '194048'
            },
        },
        'REL12' => {
            'FA_GSI' => {
                'vms' => '12',
                'mem' => '381440'
            },
            'FA_HCM' => {
                'vms' => '9',
                'mem' => '182784'
            },
            'FA_CRM' => {
                'vms' => '9',
                'mem' => '194048'
            },
        },
    }
);

our @createMandatoryParams = (
    'DB_VERSION', 'DG_LISTENER_NAME', 'DG_LISTENER_PORT',
    'EMAIL_ID', 'EM_REGISTRATION', 'EM_UPLOAD_PORT', 'ENV_TYPE', 'FA_DB_NAME',
    'FA_DB_PORT', 'FA_DB_UNIQUE_NAME', 'FA_HVPASSWD', 'FA_HVUSER', 'FA_HYPERVISOR',
    'GRID_HOME', 'IDM_DB_NAME', 'IDM_DB_PORT', 'IDM_DB_UNIQUE_NAME',
    'IS_STANDBY', 'OIM_DB_NAME', 'OIM_DB_PORT', 'OIM_DB_UNIQUE_NAME',
    'OMS_HOST_NAME', 'ORACLE_BASE', 'ORACLE_HOME', 'PILLAR', 'RAC_DB_HOST1',
    'RAC_DB_HOST2', 'RAC_NODE1_VIP', 'RAC_NODE2_VIP', 'RELEASE_NAME',
    'RELEASE_VERSION', 'SDI_HOST', 'STAGE_NAME', 'TAG_NAME',
    'TASC_DB_HOST', 'TASC_DB_NAME', 'WORKDIR', 'ZFS_ID'
);

our @cofappMandatoryParams = (
    'DB_VERSION', 'DG_LISTENER_NAME', 'DG_LISTENER_PORT',
    'EMAIL_ID', 'EM_REGISTRATION', 'EM_UPLOAD_PORT', 'ENV_TYPE', 'FA_DB_NAME',
    'FA_DB_PORT', 'FA_DB_UNIQUE_NAME', 'FA_HVPASSWD', 'FA_HVUSER', 'FA_HYPERVISOR',
    'GRID_HOME', 'IDM_DB_NAME', 'IDM_DB_PORT', 'IDM_DB_UNIQUE_NAME',
    'IS_STANDBY', 'OIM_DB_NAME', 'OIM_DB_PORT', 'OIM_DB_UNIQUE_NAME',
    'OMS_HOST_NAME', 'ORACLE_BASE', 'ORACLE_HOME', 'PILLAR', 'PRIMARY_SDIHOST',
    'RAC_DB_HOST1', 'RAC_DB_HOST2', 'RAC_NODE1_VIP', 'RAC_NODE2_VIP',
    'RELEASE_NAME', 'RELEASE_VERSION', 'SDI_HOST', 'STAGE_NAME',
    'TAG_NAME', 'TASC_DB_HOST', 'TASC_DB_NAME', 'WORKDIR', 'ZFS_ID'
);

1;
