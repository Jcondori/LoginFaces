CREATE OR REPLACE PROCEDURE load_trx_ar(p_org_id    NUMBER,
                                                p_user_name VARCHAR2,
                                                p_error     OUT VARCHAR2) IS
  --- jca 14/05/2014 carga transacciones con numeracion automatica en AR desde archivo csv,
  --                 no considera numeracion manual, falta crear tabal de trabajo
  v_line    NUMBER;
  v_error   VARCHAR2(1000);
  v_nro_reg NUMBER;
  n_reg     NUMBER;
  e_erro_data EXCEPTION;
  c_cuenta          intersf.sy_ar_pe_load_accounts%rowtype;
  v_set_of_books_id gl.gl_interface.set_of_books_id%TYPE;
  v_conversion_type gl.gl_daily_conversion_types.conversion_type%TYPE;
  v_cliente_id      NUMBER;
  v_direccion_id    NUMBER;
  worg_id           NUMBER;
  v_num_regi        NUMBER;
  v_tip_doc_trx     varchar2(2);
  v_flag_dir_ser    varchar2(2);
  vv_company        varchar2(10);
  vv_cost_center    varchar2(10);
  vv_ubigeo         VARCHAR2(10);
  vv_direccion      VARCHAR2(120);
  vv_urbanizacion   VARCHAR2(120);
  vv_pais           VARCHAR2(10);
  v_flag_requerido varchar2(1);
  -- documentos cargados
  CURSOR c_docs IS
    SELECT p.doc_id,
           p.transac_source,
           p.transac_serial,
           p.transac_number,
           p.num_regi
      FROM (SELECT doc_id,
                   transac_source,
                   transac_serial,
                   transac_number,
                   min(num_regi) num_regi
              FROM intersf.sy_ar_pe_load_accounts
             GROUP BY doc_id, transac_source, transac_serial, transac_number) p
     ORDER BY p.num_regi;
  -- cursor que actualiza los datos en toda la tabla
  CURSOR cur_trxs(p_doc_id         NUMBER,
                  p_transac_source VARCHAR2,
                  p_transac_serial VARCHAR2,
                  p_transac_number VARCHAR2) IS
    SELECT ROWID,
           num_regi,
           transac_date,
           transac_source,
           transac_serial,
           transac_number,
           transac_reference,
           transac_currency,
           transac_type,
           acounting_date,
           box_flow,
           payment_terms,
           vendor_id,
           tax_code,
           header_description,
           internal_notes,
           comments,
           segment1,
           segment2,
           segment3,
           segment4,
           segment5,
           segment6,
           segment7,
           segment8,
           unitary_price, --> 27/08/2013
           ubigeo,
           direccion,
           urbanizacion,
           SUBSTR(pais,1,2) pais  --> 22/06/2016
           --20180919 ssc jvalverde
           ,codproductosunat
           --

      FROM intersf.sy_ar_pe_load_accounts
     WHERE doc_id = p_doc_id
       AND transac_source = p_transac_source
       AND transac_serial = p_transac_serial
       AND transac_number = p_transac_number
     ORDER BY num_regi;
  CURSOR c_tra IS
    SELECT doc_id,
           transac_source,
           transac_serial,
           transac_number,
           line,
           transac_date,
           transac_reference,
           transac_currency,
           transac_type,
           acounting_date,
           box_flow,
           payment_terms,
           vendor_id,
           amount_product,
           unitary_price,
           segment1,
           segment2,
           segment3,
           segment4,
           segment5,
           segment6,
           segment7,
           segment8,
           tax_code,
           attribute_category,
           cust_account_id,
           address_id,
           header_description,
           comments,
           header_attribute13,
           header_attribute12,
           header_attribute11, --> 27/08/2013  NC/ND
           internal_notes, --perception, --> 11/06/2014
           motivo, --> 28/08/2014
           ubigeo,
           direccion,
           urbanizacion,
           SUBSTR(pais,1,2) pais --> 22/06/2016
           --20180919 ssc jvalverde
           ,codproductosunat
           --
      FROM intersf.sy_ar_pe_load_accounts
     ORDER BY doc_id,
              transac_source,
              transac_serial,
              transac_number,
              num_regi;
  wcreated_by NUMBER;
  lv_cod_impuesto varchar2(50);
BEGIN
  worg_id := p_org_id;
  -- PRIMERO VALIDA QUE la data cargada este bien ingresada
  FOR r_docs IN c_docs LOOP
    -- valida existencia del cliente
    BEGIN
      --Aqui se saca cliente_id, direccion_id
      SELECT ac.cust_account_id, max(ad.address_id)
        INTO v_cliente_id, v_direccion_id
        FROM ar.hz_cust_accounts       ac,
             ar.hz_cust_acct_sites_all sit,
             ar.hz_cust_site_uses_all  USE,
             apps.ra_addresses_all     ad,
             ar.hz_parties             par
       WHERE ac.cust_account_id = sit.cust_account_id
         AND sit.cust_acct_site_id = USE.cust_acct_site_id
         AND USE.site_use_code = 'BILL_TO'
         AND sit.party_site_id = ad.party_site_id
         AND par.party_id = ac.party_id
         AND par.tax_reference = r_docs.doc_id
         AND USE.org_id = sit.org_id
         AND sit.org_id = ad.org_id
         AND ad.org_id = worg_id
         AND ac.status = 'A'
       GROUP BY ac.cust_account_id;
    EXCEPTION
      WHEN NO_DATA_FOUND THEN
        v_error := 'Linea ' || r_docs.num_regi ||
                   ' - Cliente no encontrado, (RUC: ' || r_docs.doc_id ||
                   ' Origen: ' || r_docs.transac_source || ' Serie: ' ||
                   r_docs.transac_serial || ' # factura: ' ||
                   r_docs.transac_number || ')';
        RAISE e_erro_data;
      WHEN OTHERS THEN
        v_error := 'Linea ' || r_docs.num_regi ||
                   ' - Cliente no encontrado, (RUC: ' || r_docs.doc_id ||
                   ' Origen: ' || r_docs.transac_source || ' Serie: ' ||
                   r_docs.transac_serial || ' # factura: ' ||
                   r_docs.transac_number || ')-' || SQLERRM;
        RAISE e_erro_data;
    END;
    -- valida serie del documento
    /*      BEGIN
       v_line := to_number(r_docs.transac_serial);
    EXCEPTION
       WHEN OTHERS THEN
          v_error := 'Serie del documento no es numerico, (RUC: ' || r_docs.doc_id ||
                     ' Origen: ' || r_docs.transac_source || ' Serie: ' || r_docs.transac_serial ||
                     ' # factura: ' || r_docs.transac_number || ')';
          RAISE e_erro_data;
    END;*/
    -- valida numero del documento
    BEGIN
      v_line := to_number(r_docs.transac_number);
    EXCEPTION
      WHEN OTHERS THEN
        v_error := 'Numero del documento no es numerico, (RUC: ' ||
                   r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                   ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                   r_docs.transac_number || ')';
        RAISE e_erro_data;
    END;
    v_line := 0;
    FOR r_trx IN cur_trxs(r_docs.doc_id,
                          r_docs.transac_source,
                          r_docs.transac_serial,
                          r_docs.transac_number) LOOP
      v_line := v_line + 1;
      IF v_line = 1 THEN
        -- Valida que la primera linea se haya llenado con todos los datos.
        -- Valida descripcion de la cabecera.
        IF r_trx.header_description IS NULL THEN
          v_error := '# Lin: ' || r_trx.num_regi ||
                     ' Documento no tiene glosa descriptiva, (RUC: ' ||
                     r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                     ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                     r_docs.transac_number || ')';
          RAISE e_erro_data;
        END IF;
        -- Valida fecha de la venta.
        IF r_trx.transac_date IS NULL THEN
          v_error := '# Lin: ' || r_trx.num_regi ||
                     ' Documento no tiene fecha de transaccion, (RUC: ' ||
                     r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                     ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                     r_docs.transac_number || ')';
          RAISE e_erro_data;
        END IF;
        -- Valida divisa del documento
        IF r_trx.transac_currency IS NULL THEN
          v_error := '# Lin: ' || r_trx.num_regi ||
                     ' Documento no tiene divisa, (RUC: ' || r_docs.doc_id ||
                     ' Origen: ' || r_docs.transac_source || ' Serie: ' ||
                     r_docs.transac_serial || ' # factura: ' ||
                     r_docs.transac_number || ')';
          RAISE e_erro_data;
        END IF;
        -- Valida tipo de transaccion
        IF r_trx.transac_type IS NULL THEN
          v_error := '# Lin: ' || r_trx.num_regi ||
                     ' Documento no tiene tipo, (RUC: ' || r_docs.doc_id ||
                     ' Origen: ' || r_docs.transac_source || ' Serie: ' ||
                     r_docs.transac_serial || ' # factura: ' ||
                     r_docs.transac_number || ')';
          RAISE e_erro_data;
        END IF;
        -- Valida fecha contable
        IF r_trx.acounting_date IS NULL THEN
          v_error := '# Lin: ' || r_trx.num_regi ||
                     ' Documento no tiene fecha contable, (RUC: ' ||
                     r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                     ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                     r_docs.transac_number || ')';
          RAISE e_erro_data;
        END IF;
        -- valida flujo de caja
        IF r_trx.box_flow IS NULL THEN
          v_error := '# Lin: ' || r_trx.num_regi ||
                     ' Documento no tiene flujo de caja, (RUC: ' ||
                     r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                     ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                     r_docs.transac_number || ')';
          RAISE e_erro_data;
        END IF;
        -- valida terminos de pago
        IF r_trx.unitary_price > 0 THEN
          IF r_trx.payment_terms IS NULL THEN
            -->  27/08/2013 PARA LAS nc
            v_error := '# Lin: ' || r_trx.num_regi ||
                       ' Documento no tiene terminos de pago, (RUC: ' ||
                       r_docs.doc_id || ' Origen: ' ||
                       r_docs.transac_source || ' Serie: ' ||
                       r_docs.transac_serial || ' # factura: ' ||
                       r_docs.transac_number || ')';
            RAISE e_erro_data;
          END IF;
        END IF;
        -- valida vendedor
        IF r_trx.vendor_id IS NULL THEN
          v_error := '# Lin: ' || r_trx.num_regi ||
                     ' Documento no tiene vendedor, (RUC: ' ||
                     r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                     ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                     r_docs.transac_number || ')';
          RAISE e_erro_data;
        END IF;
        -- valida codigo de impuesto, debe ser S o N
        --IF r_trx.tax_code NOT IN ('S', 'N') THEN
        IF r_trx.tax_code NOT IN ('1', '2', '3') THEN
          v_error := '# Lin: ' || r_trx.num_regi ||
                     ' Documento tiene Codigo de impuesto erroneo, (RUC: ' ||
                     r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                     ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                     r_docs.transac_number || ')';
          RAISE e_erro_data;
        END IF;
        SELECT *
          INTO c_cuenta
          FROM intersf.sy_ar_pe_load_accounts
         WHERE ROWID = r_trx.ROWID;
        -- JQV 10/10/2016 - Se agrega la lA?gica para obtener la direcciA?n del servicio automaticamente
        ---------------------------------------------------------------------------------------------
        BEGIN
          SELECT NVL(attribute5, 'N')
            INTO v_flag_dir_ser
            FROM ar.ra_cust_trx_types_all
           WHERE org_id = worg_id
             AND upper(name) = upper(r_trx.transac_type);
        EXCEPTION
          WHEN OTHERS THEN
            v_flag_dir_ser := 'N';
        END;

        BEGIN
          SELECT ubigeo
            INTO vv_ubigeo
            FROM intersf.sy_ar_pe_load_accounts
           WHERE ROWID = r_trx.ROWID;
        EXCEPTION
          WHEN OTHERS THEN
            vv_ubigeo := '';
        END;

        IF v_flag_dir_ser = 'Y' THEN
          -- Valida el direcciA?n de servicio
          IF vv_ubigeo IS NULL THEN
            BEGIN
              SELECT segment1, segment3
                INTO vv_company, vv_cost_center
                FROM (SELECT sapl.segment1, sapl.segment3
                        FROM intersf.sy_ar_pe_load_accounts sapl
                       ORDER BY sapl.amount_product * sapl.unitary_price) TEMP
               WHERE ROWNUM = 1;
            EXCEPTION
              WHEN OTHERS THEN
                vv_company     := '';
                vv_cost_center := '';
            END;
            IF vv_company IS NOT NULL THEN
              INTERSF.SF_AR_DIR_SERV_PKG.pr_get_dir_serv_val(vv_company,
                                                             vv_cost_center,
                                                             vv_ubigeo,
                                                             vv_direccion,
                                                             vv_urbanizacion,
                                                             vv_pais);
            END IF;
          ELSE
            vv_ubigeo       := r_trx.ubigeo;
            vv_direccion    := r_trx.direccion;
            vv_urbanizacion := r_trx.urbanizacion;
            vv_pais         := r_trx.pais;
          END IF;
        ELSE
          vv_ubigeo       := '';
          vv_direccion    := '';
          vv_urbanizacion := '';
          vv_pais         := '';
        END IF;
        -- Fin  de secciA?n de automatizaciA?n de direcciA?n de servicio
      END IF;
      -- actualiza los datos de la primera linea.
      UPDATE intersf.sy_ar_pe_load_accounts
         SET line               = v_line,
             transac_date       = c_cuenta.transac_date,
             transac_currency   = c_cuenta.transac_currency,
             transac_type       = c_cuenta.transac_type,
             acounting_date     = c_cuenta.acounting_date,
             box_flow           = c_cuenta.box_flow,
             payment_terms      = c_cuenta.payment_terms,
             vendor_id          = c_cuenta.vendor_id,
             header_description = c_cuenta.header_description,
             comments           = c_cuenta.comments,
             --JQV 10/10/2016 - DirecciA?n de Servicio
             ubigeo             = vv_ubigeo,
             direccion          = vv_direccion,
             urbanizacion       = vv_urbanizacion,
             pais               = vv_pais,
             --Fin - DirecciA?n de Servicio
             cust_account_id    = v_cliente_id,
             address_id         = v_direccion_id,
             internal_notes     = c_cuenta.internal_notes
       WHERE ROWID = r_trx.ROWID;
    END LOOP;
    FOR r_trx IN cur_trxs(r_docs.doc_id,
                          r_docs.transac_source,
                          r_docs.transac_serial,
                          r_docs.transac_number) LOOP
      SELECT *
        INTO c_cuenta
        FROM intersf.sy_ar_pe_load_accounts
       WHERE ROWID = r_trx.ROWID;
      -- validation de termino de pago
      IF r_trx.unitary_price > 0 THEN
        -->  27/08/2013  PARA LAS NC
        SELECT count(1)
          INTO n_reg
          FROM ar.ra_terms_tl
         WHERE language = userenv('LANG')
           AND upper(name) = upper(r_trx.payment_terms);
        IF n_reg = 0 THEN
          v_error := '# Lin: ' || r_trx.num_regi ||
                     ' termino de pago no registrado, (RUC: ' ||
                     r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                     ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                     r_docs.transac_number || ' Termino pago: ' ||
                     r_trx.payment_terms || ')';
          RAISE e_erro_data;
        ELSE
          SELECT name
            INTO c_cuenta.payment_terms
            FROM ar.ra_terms_tl
           WHERE language = userenv('LANG')
             AND upper(name) = upper(r_trx.payment_terms)
             AND ROWNUM = 1;
        END IF;
      END IF;
      -- Valida el tipo transaccion
      SELECT count(1)
        INTO n_reg
        FROM ar.ra_cust_trx_types_all
       WHERE org_id = worg_id
         AND upper(name) = upper(r_trx.transac_type);
      IF n_reg = 0 THEN
        v_error := '# Lin: ' || r_trx.num_regi ||
                   ' tipo de transaccion no registrado, (RUC: ' ||
                   r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                   ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                   r_docs.transac_number || ' Tipo Transaccion: ' ||
                   r_trx.transac_type || ')';
        RAISE e_erro_data;
      ELSE
        SELECT name, Attribute14
          INTO c_cuenta.transac_type, v_tip_doc_trx -->  28/08/2014
          FROM ar.ra_cust_trx_types_all
         WHERE org_id = worg_id
           AND upper(name) = upper(r_trx.transac_type)
           AND ROWNUM = 1;
      END IF;
      --Valida el codigo de la moneda.
      SELECT count(1)
        INTO v_num_regi
        FROM apps.fnd_currencies_vl
      --applsys.fnd_currencies
       WHERE currency_code = r_trx.transac_currency;
      IF v_num_regi = 0 THEN
        v_error := '# Lin: ' || r_trx.num_regi ||
                   ' tipo de divisa invalido, (RUC: ' || r_docs.doc_id ||
                   ' Origen: ' || r_docs.transac_source || ' Serie: ' ||
                   r_docs.transac_serial || ' # factura: ' ||
                   r_docs.transac_number || ' Tipo divisa: ' ||
                   r_trx.transac_currency || ')';
        RAISE e_erro_data;
      END IF;
      -- Valida flujo de caja
      SELECT count(1)
        INTO n_reg
        FROM apps.fnd_flex_values val, apps.fnd_flex_value_sets se
       WHERE se.flex_value_set_id = val.flex_value_Set_id
         AND se.flex_value_set_name = 'SAGA_FLUJO_CAJA'
         AND val.flex_value = r_trx.box_flow;
      IF n_reg = 0 THEN
        v_error := '# Lin: ' || r_trx.num_regi ||
                   ' flujo de caja invalido, (RUC: ' || r_docs.doc_id ||
                   ' Origen: ' || r_docs.transac_source || ' Serie: ' ||
                   r_docs.transac_serial || ' # factura: ' ||
                   r_docs.transac_number || ' Flujo de caja: ' ||
                   r_trx.box_flow || ')';
        RAISE e_erro_data;
      END IF;
      -- Valida segmento 1.
      SELECT count(1)
        INTO n_reg
        FROM apps.fnd_flex_values val, apps.fnd_flex_value_sets se
       WHERE se.flex_value_set_id = val.flex_value_Set_id
         AND se.flex_value_set_name = 'SAGA_CG_COMPANIA'
         AND val.flex_value = r_trx.segment1;
      IF n_reg = 0 THEN
        v_error := '# Lin: ' || r_trx.num_regi ||
                   ' Segmento 1 (compa?ia) invalido, (RUC: ' ||
                   r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                   ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                   r_docs.transac_number || ' Segmento 1: ' ||
                   r_trx.segment1 || ')';
        RAISE e_erro_data;
      END IF;
      -- Valida segmento 2.
      SELECT count(1)
        INTO n_reg
        FROM apps.fnd_flex_values val, apps.fnd_flex_value_sets se
       WHERE se.flex_value_set_id = val.flex_value_Set_id
         AND se.flex_value_set_name = 'SAGA_CG_CUENTA'
         AND val.flex_value = r_trx.segment2;
      IF n_reg = 0 THEN
        v_error := '# Lin: ' || r_trx.num_regi ||
                   ' Segmento 2 (cuenta) invalido, (RUC: ' || r_docs.doc_id ||
                   ' Origen: ' || r_docs.transac_source || ' Serie: ' ||
                   r_docs.transac_serial || ' # factura: ' ||
                   r_docs.transac_number || ' Segmento 2: ' ||
                   r_trx.segment2 || ')';
        RAISE e_erro_data;
      END IF;
      -- Valida segmento 3.
      SELECT count(1)
        INTO n_reg
        FROM apps.fnd_flex_values val, apps.fnd_flex_value_sets se
       WHERE se.flex_value_set_id = val.flex_value_Set_id
         AND se.flex_value_set_name = 'SAGA_CG_CENTRO_COSTO'
         AND val.flex_value = r_trx.segment3;
      IF n_reg = 0 THEN
        v_error := '# Lin: ' || r_trx.num_regi ||
                   ' Segmento 3 (centro costo) invalido, (RUC: ' ||
                   r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                   ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                   r_docs.transac_number || ' Segmento 3: ' ||
                   r_trx.segment3 || ')';
        RAISE e_erro_data;
      END IF;
      -- Valida segmento 4.
      SELECT count(1)
        INTO n_reg
        FROM apps.fnd_flex_values val, apps.fnd_flex_value_sets se
       WHERE se.flex_value_set_id = val.flex_value_Set_id
         AND se.flex_value_set_name = 'SAGA_CG_ANALISIS_IMPUTACION'
         AND val.flex_value = r_trx.segment4;
      IF n_reg = 0 THEN
        v_error := '# Lin: ' || r_trx.num_regi ||
                   ' Segmento 4 (analisis imputacion) invalido, (RUC: ' ||
                   r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                   ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                   r_docs.transac_number || ' Segmento 4: ' ||
                   r_trx.segment4 || ')';
        RAISE e_erro_data;
      END IF;
      -- Valida segmento 5.
      SELECT count(1)
        INTO n_reg
        FROM apps.fnd_flex_values val, apps.fnd_flex_value_sets se
       WHERE se.flex_value_set_id = val.flex_value_Set_id
         AND se.flex_value_set_name = 'SAGA_CG_CONSOLIDADOR'
         AND val.flex_value = r_trx.segment5;
      IF n_reg = 0 THEN
        v_error := '# Lin: ' || r_trx.num_regi ||
                   ' Segmento 5 (consolidador) invalido, (RUC: ' ||
                   r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                   ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                   r_docs.transac_number || ' Segmento 5: ' ||
                   r_trx.segment5 || ')';
        RAISE e_erro_data;
      END IF;
      -- Valida segmento 6.
      SELECT count(1)
        INTO n_reg
        FROM apps.fnd_flex_values val, apps.fnd_flex_value_sets se
       WHERE se.flex_value_set_id = val.flex_value_Set_id
         AND se.flex_value_set_name = 'SAGA_CG_LINEA'
         AND val.flex_value = r_trx.segment6;
      IF n_reg = 0 THEN
        v_error := '# Lin: ' || r_trx.num_regi ||
                   ' Segmento 6 (linea) invalido, (RUC: ' || r_docs.doc_id ||
                   ' Origen: ' || r_docs.transac_source || ' Serie: ' ||
                   r_docs.transac_serial || ' # factura: ' ||
                   r_docs.transac_number || ' Segmento 6: ' ||
                   r_trx.segment6 || ')';
        RAISE e_erro_data;
      END IF;
      -- Valida segmento 7.
      SELECT count(1)
        INTO n_reg
        FROM apps.fnd_flex_values val, apps.fnd_flex_value_sets se
       WHERE se.flex_value_set_id = val.flex_value_Set_id
         AND se.flex_value_set_name = 'SAGA_CG_PROYECTO'
         AND val.flex_value = r_trx.segment7;
      IF n_reg = 0 THEN
        v_error := '# Lin: ' || r_trx.num_regi ||
                   ' Segmento 7 (proyecto) invalido, (RUC: ' ||
                   r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                   ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                   r_docs.transac_number || ' Segmento 7: ' ||
                   r_trx.segment7 || ')';
        RAISE e_erro_data;
      END IF;
      -- Valida segmento 8.
      SELECT count(1)
        INTO n_reg
        FROM apps.fnd_flex_values val, apps.fnd_flex_value_sets se
       WHERE se.flex_value_set_id = val.flex_value_Set_id
         AND se.flex_value_set_name like 'SAGA_CG_USO%FUTURO'
         AND val.flex_value = r_trx.segment8;
      IF n_reg = 0 THEN
        v_error := '# Lin: ' || r_trx.num_regi ||
                   ' Segmento 8 (uso futuro) invalido, (RUC: ' ||
                   r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                   ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                   r_docs.transac_number || ' Segmento 8: ' ||
                   r_trx.segment8 || ')';
        RAISE e_erro_data;
      END IF;

      --JQV 10/10/2016 - DirecciA?n de Servicio
      BEGIN
        SELECT NVL(attribute5, 'N')
          INTO v_flag_dir_ser
          FROM ar.ra_cust_trx_types_all
         WHERE org_id = worg_id
           AND upper(name) = upper(r_trx.transac_type);
      EXCEPTION
        WHEN OTHERS THEN
          v_flag_dir_ser := 'N';
      END;

      IF v_flag_dir_ser = 'Y' THEN
        -- Valida el cA?digo ubigeo
        SELECT count(1)
          INTO n_reg
          FROM INTERSF.SF_UBIGEO sfu
         WHERE sfu.COD_UBIGEO = r_trx.ubigeo;
        IF n_reg = 0 THEN
          v_error := '# Lin: ' || r_trx.num_regi ||
                     ' CA?digo Ubigeo no existe, (RUC: ' || r_docs.doc_id ||
                     ' Origen:' || r_docs.transac_source || ' Serie: ' ||
                     r_docs.transac_serial || ' # factura: ' ||
                     r_docs.transac_number || ' Codigo Ubigeo: ' ||
                     r_trx.ubigeo || ')';
          RAISE e_erro_data;
        END IF;
        -- Valida el cA?digo pais
        SELECT count(1)
          INTO n_reg
          FROM APPS.FND_TERRITORIES_VL ftv
         WHERE ftv.TERRITORY_CODE = r_trx.pais;
        IF n_reg = 0 THEN
          v_error := '# Lin: ' || r_trx.num_regi ||
                     ' CA?digo PaA?s no existe, (RUC: ' || r_docs.doc_id ||
                     ' Origen: ' || r_docs.transac_source || ' Serie: ' ||
                     r_docs.transac_serial || ' # factura: ' ||
                     r_docs.transac_number || ' Codigo Pais: ' ||
                     r_trx.pais || ')';
          RAISE e_erro_data;
        END IF;
      END IF;

      -- Valida codigo producto sunat --ssc jvalverde 20180919
      SELECT count(1)
        INTO n_reg
        FROM apps.fnd_flex_values val, apps.fnd_flex_value_sets se
       WHERE se.flex_value_set_id = val.flex_value_Set_id
         AND se.flex_value_set_name = 'SSC_AR_FE_COD_PRODUCTO_SUNAT'
         AND val.flex_value = replace(r_trx.codproductosunat,chr(13));
         --Obtenere flag de obligatoriedad para  el codigo de producto sunat
         SELECT distinct REQUIRED_FLAG
           into v_flag_requerido
          FROM apps.FND_DESCR_FLEX_COL_USAGE_VL
         WHERE (APPLICATION_ID = 222)
           and (DESCRIPTIVE_FLEXFIELD_NAME LIKE 'RA_CUSTOMER_TRX_LINES')
           and (DESCRIPTIVE_FLEX_CONTEXT_CODE = 'Global Data Elements')
           and application_column_name='ATTRIBUTE3' ;

      if(v_flag_requerido='N')then

            if (replace(r_trx.codproductosunat,chr(13)) is not null) then

              --if(replace(r_trx.codproductosunat,chr(13))!='')then
                 IF (n_reg = 0) THEN
                  v_error := '# Lin: ' || r_trx.num_regi ||
                             ' Codigo producto Sunat invalido, (RUC: ' ||
                             r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                             ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                             r_docs.transac_number || ' Codigo producto Sunat: ' ||
                             replace(r_trx.codproductosunat,chr(13)) || ')';
                  RAISE e_erro_data;
                 END IF;
              --end if;
            end if;
      else
        IF (n_reg = 0) THEN
                  v_error := '# Lin: ' || r_trx.num_regi ||
                             ' Codigo producto Sunat invalido, (RUC: ' ||
                             r_docs.doc_id || ' Origen: ' || r_docs.transac_source ||
                             ' Serie: ' || r_docs.transac_serial || ' # factura: ' ||
                             r_docs.transac_number || ' Codigo producto Sunat: ' ||
                             replace(r_trx.codproductosunat,chr(13)) || ')';
                  RAISE e_erro_data;
         END IF;
      end if;

      -------------valida codigo impuesto exite en lookup--------------------

        SELECT count(1)
          INTO n_reg
          FROM apps.FND_LOOKUP_VALUES_VL
          WHERE LOOKUP_TYPE = 'SF_COD_IMPUESTO_IMP_MASIVA' AND LOOKUP_CODE =r_trx.tax_code;
        IF n_reg = 0 THEN
          v_error := '# Lin: ' || r_trx.num_regi ||
                     ' CA?digo impuesto no existe, (RUC: ' || r_docs.doc_id ||
                     ' Origen:' || r_docs.transac_source || ' Serie: ' ||
                     r_docs.transac_serial || ' # factura: ' ||
                     r_docs.transac_number || ' Codigo impuesto: ' ||
                     r_trx.tax_code || ')';
          RAISE e_erro_data;
        END IF;


      --Fin - DirecciA?n de Servicio

    END LOOP;
  END LOOP;
  -- id del usuario
  SELECT user_id
    INTO wcreated_by
    FROM applsys.fnd_user
   WHERE user_name = p_user_name;
  /*
      SELECT appar.org_id
        INTO worg_id
        FROM ap.ap_system_parameters_all appar,
             gl.gl_sets_of_books sob
       WHERE appar.set_of_books_id = sob.set_of_books_id
         AND sob.name = 'TOTTUS_LIBRO_CONTABLE';
  */
  -- obtiene el libro contable
  SELECT set_of_books_id
    INTO v_set_of_books_id
    FROM ap.ap_system_parameters_all
   WHERE org_id = worg_id;
  -- se obtiene el codigo de tipo de conversion de venta.
  SELECT conversion_type
    INTO v_conversion_type
    FROM gl.gl_daily_conversion_types
   WHERE user_conversion_type = 'Venta';
  FOR x IN c_tra LOOP


    SELECT distinct DESCRIPTION --MEANING
       into lv_cod_impuesto
       FROM apps.FND_LOOKUP_VALUES_VL
       WHERE LOOKUP_TYPE = 'SF_COD_IMPUESTO_IMP_MASIVA' AND LOOKUP_CODE = x.tax_code;




    INSERT INTO ar.ra_interface_lines_all
      (interface_line_context,
       interface_line_attribute1,
       interface_line_attribute2,
       interface_line_attribute3,
       interface_line_attribute4,
       batch_source_name,
       set_of_books_id,
       line_type,
       description,
       currency_code,
       amount,
       cust_trx_type_name,
       term_name,
       orig_system_bill_customer_id,
       orig_system_bill_address_id,
       conversion_type,
       conversion_date,
       trx_date,
       gl_date,
       document_number,
       trx_number,
       quantity,
       unit_selling_price,
       org_id,
       header_attribute1,
       created_by,
       primary_salesrep_number,
       tax_code,
       attribute_category,
       comments,
       header_attribute13, --> 27/08/2013
       header_attribute11, --> 27/08/2013
       header_attribute12, --> 27/08/2013
       internal_notes, --> 11/06/2014
       --header_attribute3,  --> 17/08/2014
       header_attribute8, -->  28/08/2014
       header_attribute9,
       interface_line_attribute12,
       interface_line_attribute13,
       interface_line_attribute14,
       interface_line_attribute15,
       interface_line_attribute11,
       interface_line_attribute10,
       creation_date --> 01/12/2014
       -- ssc jvalverde 20180919
       ,attribute3)
    VALUES
      ('INTERNO',
       x.header_description, -- origen
       x.transac_source, -- serie,
       x.transac_number, --x.transac_serial || '-' || x.transac_number,  -- serie - factura,
       x.line,
       x.transac_source, -- origen,
       v_set_of_books_id, --set of books
       'LINE',
       x.transac_reference, -- r.cc_referencia,
       x.transac_currency, -- r.cc_moneda,
       x.amount_product * x.unitary_price, -- r.cc_monto,
       x.transac_type, -- r.cc_tipotrx,
       x.payment_terms, -- r.cc_termpago,
       x.cust_account_id,
       x.address_id,
       v_conversion_type,
       x.transac_date, --x.acounting_date, --DECODE(r.cc_moneda,'PEN',1,ptipo_cambio),
       x.transac_date, -- r.cc_fecha,
       x.acounting_date, --r.cc_fec_contable,
       null, --to_number(x.transac_serial || x.transac_number), -- to_number(r.cc_serie||r.cc_factura),
       null, --x.transac_serial || x.transac_number, -- r.cc_serie||r.cc_factura,
       x.amount_product, -- 1,
       x.unitary_price, -- r.cc_monto,
       worg_id,
       x.box_flow, --r.cc_flujo,
       wcreated_by,
       x.vendor_id, --r.cc_vendedor,
       /*decode(x.tax_code,
              '1',
              'IGV GRAVADO',
              '2',
              'IGV EXONERADO',
              '3',
              'IGV EXONERADO'),*/
       lv_cod_impuesto,
       --decode(x.attribute_category,1,'002',2,'004',3,'007'), -- referencia.
     --  decode(x.tax_code, '1', '002', '2', '004', '3', '007'),
     (select  distinct vv.attribute1
      from AR.AR_VAT_TAX_ALL_B v , fnd_flex_value_sets vs, fnd_flex_values vv
      where 1=1
        AND V.TAX_CODE =lv_cod_impuesto
        and vs.flex_value_set_name = 'SF_VALOR_CONTEXTO_SUNAT'
        and vs.flex_value_set_id = vv.flex_value_set_id
        and vv.flex_value = v.attribute12||'-'||v.attribute14||'-'||v.attribute13
		    AND V.ORG_ID=p_org_id
        And nvl(v.enabled_flag,'Y') = 'Y'
        And  trunc(sysdate) <= nvl( trunc(v.end_date), trunc(sysdate+1))
      ),--ghh 09112018

       x.comments, -- comentarios.
       x.header_attribute13, --> 27/08/2013
       x.header_attribute11, --> 27/08/2013
       x.header_attribute12, --> 27/08/2013
       x.internal_notes, --> 11/06/2014
       --x.perception,--> 17/08/2014
       DECODE(v_tip_doc_trx, '08', x.motivo, null), -->  28/08/2014
       DECODE(v_tip_doc_trx, '07', x.motivo, null),
       x.ubigeo,
       substr(x.direccion,1,30), --TAMAA?O MA?XIMO DE INTERFACE 30
       x.urbanizacion,
       x.pais,
       substr(x.direccion,31,30),
       substr(x.direccion,61,30),
       SYSDATE -->  01/12/2014
       ,replace(x.codproductosunat,chr(13)));
    INSERT INTO ar.ra_interface_distributions_all
      (interface_line_context,
       interface_line_attribute1,
       interface_line_attribute2,
       interface_line_attribute3,
       interface_line_attribute4,
       segment1,
       segment2,
       segment3,
       segment4,
       segment5,
       segment6,
       segment7,
       segment8,
       amount,
       org_id,
       account_class,
       interface_line_attribute12,
       interface_line_attribute13,
       interface_line_attribute14,
       interface_line_attribute15,
       interface_line_attribute11,
       interface_line_attribute10,
       creation_date)
    VALUES
      ('INTERNO',
       x.header_description, -- origen,
       x.transac_source, -- serie,
       x.transac_number, --x.transac_serial || '-' || x.transac_number,  -- serie||'-'||factura,
       x.line, -- 1,
       x.segment1, -- seg1,
       x.segment2, -- seg2,
       x.segment3, -- seg3,
       x.segment4, -- seg4,
       x.segment5, -- seg5,
       x.segment6, -- seg6,
       x.segment7, -- seg7,
       x.segment8, -- seg8,
       x.amount_product * x.unitary_price, -- monto,
       worg_id,
       'REV',
       x.ubigeo,
       substr(x.direccion,1,30), --TAMAA?O MA?XIMO DE INTERFACE 30
       x.urbanizacion,
       x.pais,
       substr(x.direccion,31,30),
       substr(x.direccion,61,30),
       sysdate);
    INSERT INTO ar.ra_interface_salescredits_all
      (interface_line_context,
       interface_line_attribute1,
       interface_line_attribute2,
       interface_line_attribute3,
       interface_line_attribute4,
       sales_credit_amount_split,
       salesrep_number,
       sales_credit_type_name,
       interface_line_attribute12,
       interface_line_attribute13,
       interface_line_attribute14,
       interface_line_attribute15,
       interface_line_attribute11,
       interface_line_attribute10,
       creation_date)
    VALUES
      ('INTERNO',
       x.header_description, -- origen,
       x.transac_source, -- serie,
       x.transac_number, --x.transac_serial || '-' || x.transac_number,  -- serie||'-'||factura,
       x.line, -- 1,
       x.amount_product * x.unitary_price, -- monto,
       x.vendor_id, --r.cc_vendedor,
       'Quota Sales Credit',
       x.ubigeo,
       substr(x.direccion,1,30), --TAMAA?O MA?XIMO DE INTERFACE 30
       x.urbanizacion,
       x.pais,
       substr(x.direccion,31,30),
       substr(x.direccion,61,30),
       sysdate);
  END LOOP;
  COMMIT;
EXCEPTION
  WHEN e_erro_data THEN
    p_error := v_error;
END load_trx_ar;
