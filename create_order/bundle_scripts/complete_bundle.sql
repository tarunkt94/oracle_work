DECLARE
  l_e                      tas.tas_e_t;
  l_order_item_list        tas.tas_order_item_list_t;
  l_order_item             tas.tas_order_item_t;
  l_order                  tas.tas_order_t;
  l_svc_admin_contact_info tas.tas_person_info_t;
  l_user_contact_info      tas.tas_person_info_t;
  l_sys_admin_contact_info tas.tas_person_info_t;
  l_acct_admin_contact_info tas.tas_person_info_t;
  l_assoc_item1            tas.tas_association_item_t;
  l_assoc_item2            tas.tas_association_item_t;
  l_assoc_list             tas.tas_association_list_t;
  l_properties   tas.tas_key_value_list_t;
  l_dr_config			VARCHAR2(20);
BEGIN
  l_properties :=
    tas.tas_key_value_list_t(
      tas.tas_key_value_t(tas.tas_oq_order_pkg.ORDITEM_PROP_ENT_NAME, 'My Blueberry Enterprise'),
      tas.tas_key_value_t(tas.tas_oq_order_pkg.ORDITEM_PROP_ENT_SHORT_NAME, 'BLUE'),
      tas.tas_key_value_t(tas.tas_oq_order_pkg.ORDITEM_PROP_ENT_COUNTRY_CODE, 'US'),
      tas.tas_key_value_t(tas.tas_oq_order_pkg.ORDITEM_PROP_ADDRESS_LINE1, '123 Blueberry Hill Lane')
    );
  l_svc_admin_contact_info := tas.tas_person_info_t(
        given_name  => 'ServiceAdminGivenName',
        family_name => 'ServiceAdminFamilyName',
        email => 'tarun.karamshetty@oracle.com');
 l_user_contact_info := tas.tas_person_info_t(
      given_name  => 'UserContactGivenName',
      family_name => 'UserContactFamilyName',
      email => 'tarun.karamshetty@oracle.com');
  l_sys_admin_contact_info := tas.tas_person_info_t(
      given_name  => 'SystemAdminGivenName',
      family_name => 'SystemAdminFalilyName',
      email => 'tarun.karamshetty@oracle.com');
  l_acct_admin_contact_info := tas.tas_person_info_t(
      given_name  => 'AccountAdminGivenName',
      family_name => 'AcountAdminFalilyName',
      email => 'tarun.karamshetty@oracle.com');

  l_order_item := tas.tas_order_item_t(
        service_type               => NULL,
        operation_type             => 'ONBOARDING',
        subscription_type          => tas.tas_oq_order_pkg.PRODUCTION,
        service_display_name       => '&2',
        service_configuration      => NULL,
        service_admin_user_name    => 'fadradmin',
        service_admin_contact_info => l_svc_admin_contact_info,
        description                => NULL);
	l_dr_config := '&1';
	IF l_dr_config <> 'null' THEN
    l_properties.extend(1);
		l_properties(l_properties.LAST) := tas.tas_key_value_t('DR_CONFIG',l_dr_config);
	END IF;
	l_order_item.item_id := &3;
  l_order_item.properties := l_properties;
  l_order_item.system_id := null;
  l_order_item.system_name := 'fadrsdihcm'|| '&2';
  l_order_item.system_admin_user_name := 'fadradmin';
  l_order_item.system_admin_contact_info := l_sys_admin_contact_info;

  l_order_item_list := tas.tas_order_item_list_t();
  l_order_item_list.extend(1);
  l_order_item_list(1) := l_order_item;

  l_assoc_list := null;

  l_order := tas.tas_order_t(
      order_id => 'orderid', --external_order_id of the logical order
      services => l_order_item_list);
  l_order.user_contact_info := l_user_contact_info;
  l_order.association_list := l_assoc_list;

  tas.tas_oq_order_pkg.complete_order(o_e             => l_e,
                                      i_order         => l_order,
                                      i_order_passkey => '&4');

commit;
  If (l_e Is Not Null) Then
    dbms_output.put_line('Error Code: ' || l_e.e_code);
    dbms_output.put_line('Error Message: ' || l_e.e_errm);
    If (l_e.nested_exception Is Not Null) Then
      dbms_output.put_line('...Nested Error Code: ' || l_e.nested_exception.e_code);
      dbms_output.put_line('...Nested Error Message: ' || l_e.nested_exception.e_errm);
    End If;
    Return;
  End If;

END;
/
