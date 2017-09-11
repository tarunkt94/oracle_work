DECLARE
  l_date         DATE;
  l_gsi_order    tas.tas_gsi_order_t;
  l_line_item    tas.tas_gsi_line_item_t;
  l_composite_li tas.tas_gsi_line_item_t;
  l_li_sc_list   tas.tas_gsi_li_service_comp_list_t;
  l_li_sc        tas.tas_gsi_li_service_component_t;
  l_li_nsc_list  tas.tas_gsi_li_component_list_t;
  l_li_nsc       tas.tas_gsi_li_component_t;
  l_line_items   tas.tas_gsi_line_item_list_t;
  l_response     tas.tas_gsi_response_t;
  l_response_items tas.tas_gsi_response_item_list_t;
  l_e            tas.tas_e_t;
  l_properties   tas.tas_key_value_list_t;
  l_properties_gsi_order   tas.tas_key_value_list_t;
BEGIN
  l_date := sys_extract_utc(systimestamp);
  l_line_items := tas.tas_gsi_line_item_list_t();

  l_properties := tas.tas_key_value_list_t(tas.tas_key_value_t('PRODUCT_RELEASE_VERSION','11.13.17.5.0'),tas.tas_key_value_t('TAGS','RGNL1'),tas.tas_key_value_t('OPERATIONAL_POLICY','ENTERPRISE'),tas.tas_key_value_t('IDM_FEDERATION', 'false'));

  l_composite_li := tas.tas_gsi_line_item_t(
                                   line_id        => 1,
                                   subscription_id => NULL,
                                   item_name      => NULL,
                                   start_date     => l_date,
                                   end_date       => l_date + 30,
                                   overage_billed => 'N',
                                   properties     => l_properties,
                                   service_group_name => upper('&3'),
                                   service_components => NULL
                                 );

  l_li_sc_list :=  tas.tas_gsi_li_service_comp_list_t();
  l_li_sc_list.extend( 4 );

  l_properties := tas.tas_key_value_list_t( tas.tas_key_value_t('K1', 'V1'), tas.tas_key_value_t('K2', 'V2') );

  l_li_sc_list(1)  :=  tas.tas_gsi_li_service_component_t(
                          component_id    =>  'LA100001',
                          service_component_id   =>  'B87344',
                          line_id         => 100,
                          start_date      => l_date,
                          end_date        => l_date + 10,
                          properties      => l_properties,
                          components      => NULL
                       );

  l_li_nsc_list    := tas.tas_gsi_li_component_list_t();
  l_li_nsc_list.extend(2);

  l_properties(1).key := 'K1.1';
  l_li_nsc_list(1) := tas.tas_gsi_li_component_t(
                          component_id    =>  'LA100001_1',
                          properties      =>  l_properties
                      );

  l_properties(1).key := 'K1.2';
  l_li_nsc_list(2) := tas.tas_gsi_li_component_t(
                          component_id    =>  'LA100001_2',
                          properties      =>  l_properties
                      );

  l_li_sc_list(1).components := l_li_nsc_list;

  l_li_sc_list(2)  :=  tas.tas_gsi_li_service_component_t(
                          component_id    =>  'LA100002',
                          service_component_id   =>  'B85244',
                          line_id         => 200,
                          start_date      => l_date,
                          end_date        => l_date + 10,
                          properties      => NULL,
                          components      => NULL
                       );

  l_li_nsc_list    := tas.tas_gsi_li_component_list_t();
  l_li_nsc_list.extend(2);

  l_properties(1).key := 'K2.1';
  l_li_nsc_list(1) := tas.tas_gsi_li_component_t(
                          component_id    =>  'LA100002_1',
                          properties      =>  l_properties
                      );

  l_properties(1).key := 'K2.2';
  l_li_nsc_list(2) := tas.tas_gsi_li_component_t(
                          component_id    =>  'LA100002_2',
                          properties      =>  l_properties
                      );
  l_li_sc_list(2).components := l_li_nsc_list;

  l_li_sc_list(3)  :=  tas.tas_gsi_li_service_component_t(
                          component_id    =>  'LA100002',
                          service_component_id   =>  'B81510',
                          line_id         => 200,
                          start_date      => l_date,
                          end_date        => l_date + 10,
                          properties      => NULL,
                          components      => NULL
                       );

  l_li_nsc_list    := tas.tas_gsi_li_component_list_t();
  l_li_nsc_list.extend(2);

  l_properties(1).key := 'K3.1';
  l_li_nsc_list(1) := tas.tas_gsi_li_component_t(
                          component_id    =>  'LA100002_1',
                          properties      =>  l_properties
                      );

  l_properties(1).key := 'K3.2';
  l_li_nsc_list(2) := tas.tas_gsi_li_component_t(
                          component_id    =>  'LA100002_2',
                          properties      =>  l_properties
                      );
  l_li_sc_list(2).components := l_li_nsc_list;

  l_li_sc_list(4)  :=  tas.tas_gsi_li_service_component_t(
                          component_id    =>  'LA100002',
                          service_component_id   =>  'B85245',
                          line_id         => 200,
                          start_date      => l_date,
                          end_date        => l_date + 10,
                          properties      => NULL,
                          components      => NULL
                       );

  l_li_nsc_list    := tas.tas_gsi_li_component_list_t();
  l_li_nsc_list.extend(2);

  l_properties(1).key := 'K4.1';
  l_li_nsc_list(1) := tas.tas_gsi_li_component_t(
                          component_id    =>  'LA100002_1',
                          properties      =>  l_properties
                      );

  l_properties(1).key := 'K4.2';
  l_li_nsc_list(2) := tas.tas_gsi_li_component_t(
                          component_id    =>  'LA100002_2',
                          properties      =>  l_properties
                      );
  l_li_sc_list(2).components := l_li_nsc_list;

  l_composite_li.service_components := l_li_sc_list;
  l_line_items.extend();
  l_line_items(1) := l_composite_li;

        -- Handling DR related Options
  l_properties_gsi_order := tas_key_value_list_t();
  l_properties_gsi_order.extend();
  l_properties_gsi_order(1):= tas.tas_key_value_t( 'SALES_REPS', 'pandebuyer@example.com' );
  l_properties_gsi_order.extend();
  l_properties_gsi_order(2):= tas.tas_key_value_t( 'FIELD_SEPARATOR', ':' );
  l_properties_gsi_order.extend();
  l_properties_gsi_order(3):= tas.tas_key_value_t('CUSTOMER_COUNTRY_CODE', 'US');
  if('&4' != '0') then
        l_properties_gsi_order.extend();
        if ( '&4' = 'PROV_TEST_BEFORE_PROD' ) then
                l_properties_gsi_order(4):=tas.tas_key_value_t('PROV_TEST_BEFORE_PROD', 'TRUE');
        elsif ('&4' = 'DEPLOY_TEST_INSTANCE_FALSE' ) then
                l_properties_gsi_order(4):= tas.tas_key_value_t('DEPLOY_TEST_INSTANCE', 'FALSE');
        end if;
  end if;
  l_gsi_order := tas.tas_gsi_order_t(
                       order_number => &2,
                       organization_id => &1,
                       order_date => l_date,
customer_name => 'BundleCustomer',
customer_acct_number => 'Bundle_ABC',
buyer_email => 'fadr_qa_ops_in_grp@oracle.com',
account_admin_email => 'fadr_qa_ops_in_grp@oracle.com',
                       co_term_subscription_id => null,
                       csi_number => 3560,
                       properties     => l_properties_gsi_order,
data_center_region_id => 'US1',
                       processing_date => null,
                       line_items => l_line_items);

  tas.tas_gsi_bridge_pkg.order_booked(o_e => l_e,
                                      o_response => l_response,
                                      i_order => l_gsi_order);

commit;
  If (l_e Is Not Null) Then
    -- Do something about the error.
    -- Possible error codes:
    --   tas.tas_ex_constants_pkg.TAS_ECODE_GSI_INVALID_INPUT (integer value 105)
    --   tas.tas_ex_constants_pkg.TAS_ECODE_GSI_INTERNAL_ERR  (integer value 106)
    dbms_output.put_line('Error Code: ' || l_e.e_code);
    dbms_output.put_line('Error Message: ' || l_e.e_errm);
    If (l_e.nested_exception Is Not Null) Then
      dbms_output.put_line('...Nested Error Code: ' || l_e.nested_exception.e_code);
      dbms_output.put_line('...Nested Error Message: ' || l_e.nested_exception.e_errm);
    End If;
    Return;
  End If;

  -- Process result object.
  -- Expected status if no error object was returned:
  --   tas.tas_gsi_bridge_pkg.RESPONSE_STATUS_IDS_GENERATED (varchar2 'IDS_GENERATED')
  dbms_output.put_line('Response status: ' || l_response.status);
  dbms_output.put_line('Response organization_id: ' || l_response.organization_id);
  dbms_output.put_line('Response order_number: ' || l_response.order_number);
  l_response_items := l_response.response_items;
  For i In l_response_items.FIRST..l_response_items.LAST Loop
    dbms_output.put_line('Response item line_id: ' || l_response_items(i).line_id);
    dbms_output.put_line('Response item subscription_id: ' || l_response_items(i).subscription_id);
  End Loop;

END;
/
