PROCEDURE p_load_file_nd( p_error OUT VARCHAR2, p_regi OUT NUMBER) IS
  /****************************************************************************/
  /* Módulo: Cuentas por Cobrar                                               */
  /* Programa: SFAR0033                                                       */
  /* Descripción: programa que realiza la carga del archivo a AR, genera la   */
  /* carga en la tablas de AR, para la generacion de facturas en forma        */
  /* automatica para Origenes de Importacion y numeracion automatica          */
  /* Funcionalidad: Devuelve el numero de registros actualizados en la maestra*/
  /* Creador: Julio Carrillo                                                  */
  /* Fecha: 18/05/2014                   HORA: 10:18 PM                       */
  /****************************************************************************/
  lc_cadena            VARCHAR2(1000);
  lc_cadena_aux        VARCHAR2(1000);
  lv_out_file          utl_file.file_TYPE; -- para financial
  --lv_out_file          TEXT_IO.FILE_TYPE; -- Para Report
  v_doc_id             ar.hz_parties.tax_reference%TYPE;                         -- ruc
  v_transac_source     ar.ra_interface_lines_all.interface_line_attribute2%TYPE; -- origen
  v_transac_Serial     ar.ra_interface_lines_all.interface_line_attribute2%TYPE; -- serie
  v_transac_number     ar.ra_interface_lines_all.interface_line_attribute2%TYPE; -- número de factura
  v_line               intersf.sy_ar_pe_load_accounts.line%TYPE;                 -- linea
  v_transac_date       ar.ra_interface_lines_all.trx_date%TYPE;                  -- fecha
  v_transac_reference  ar.ra_interface_lines_all.description%TYPE;               -- descripcion
  v_transac_currency   ar.ra_interface_lines_all.currency_code%TYPE;             -- divisa 
  v_transac_TYPE       ar.ra_interface_lines_all.cust_trx_TYPE_name%TYPE;        -- tipo
  v_acounting_date     ar.ra_interface_lines_all.gl_date%TYPE;                   -- fecha contable
  v_box_flow           ar.ra_interface_lines_all.header_attribute1%TYPE;         -- flujo caja
  v_payment_terms      ar.ra_interface_lines_all.term_name%TYPE;                 -- terminos de pago
  v_vendor_id          ar.ra_interface_lines_all.primary_salesrep_NUMBER%TYPE;   -- vendedor
  v_amount_product     intersf.sy_ar_pe_load_accounts.amount_product%TYPE;       -- cantidad
  v_unitary_price      ar.ra_interface_lines_all.amount%TYPE;                    -- precio unitario
  v_segment1           ar.ra_interface_distributions_all.segment1%TYPE;          -- seg1
  v_segment2           ar.ra_interface_distributions_all.segment2%TYPE;          -- seg2
  v_segment3           ar.ra_interface_distributions_all.segment3%TYPE;          -- seg3
  v_segment4           ar.ra_interface_distributions_all.segment4%TYPE;          -- seg4
  v_segment5           ar.ra_interface_distributions_all.segment5%TYPE;          -- seg5
  v_segment6           ar.ra_interface_distributions_all.segment6%TYPE;          -- seg6
  v_segment7           ar.ra_interface_distributions_all.segment7%TYPE;          -- seg7
  v_segment8           ar.ra_interface_distributions_all.segment8%TYPE;          -- seg8
  v_tax_code           ar.ra_interface_lines_all.tax_code%TYPE;                  -- tax_code
  v_attribute_category ar.ra_interface_lines_all.attribute_category%TYPE;        -- attribute_category
  v_header_description ar.ra_interface_lines_all.interface_line_attribute1%TYPE; -- header_description
  v_comments           ar.ra_interface_lines_all.comments%TYPE;                  -- comments
  v_error             VARCHAR2(1000);
  v_cad_inte          VARCHAR2(1000);
  ln_cont             NUMBER;
  v_posi              NUMBER;
  e_line_more_data    EXCEPTION;
  e_line_few_data     EXCEPTION;
  e_conversion        EXCEPTION;
  v_dat_car           VARCHAR2(1000);
  ---------------------------
  v_csc_prv						NUMBER;
  tmp_prv							NUMBER;
  v_ctr_prv						NUMBER;
  v_ins_esp						varchar2(240);
  ------------------>>
  v_tip_doc_rel varchar2(15);
  v_fec_doc_rel varchar2(25); --  DATE;
  v_num_doc_rel varchar2(50);
  v_motivo			varchar2(2);
  v_check							intersf.sy_ar_pe_load_accounts.line%TYPE;
  v_cod_prod_sunat varchar2(20); --rp
BEGIN
   ln_cont := 0;
   p_regi := 0;
   DELETE intersf.sy_ar_pe_load_accounts;  
   --lee cabecera 
--   srw.message('200','load process to AR begin...!!');
   --srw.message('200','P_FILE : '|| :p_file);
   --srw.message('200','P_ROUTE : '|| :p_path);
   -- carga la tabla temporal de los datos con el archivo de texto ingresado
   --lv_out_file  := text_io.fopen('D:\carga_prueba.csv','r');        /* para report*/
   lv_out_file := utl_file.fopen(:p_path,:p_file,'r');
   tmp_prv:=NULL;  --> 18/05/2014
   LOOP
      BEGIN
         --text_io.get_line(lv_out_file, lc_cadena);   /* para report */   
         utl_file.get_line(lv_out_file, lc_cadena);  /* para financial*/ 
      EXCEPTION
         WHEN NO_DATA_FOUND THEN
            srw.message('300',ln_cont || ' record(s) was loaded');
            EXIT;
         WHEN OTHERS THEN 
            srw.message('300','Failure reading : ' ||sqlcode || ' - '|| sqlerrm);
            EXIT;
      END;
      ln_cont := ln_cont + 1;
      -- el numero de registros a llenar es 26, cualquier otra cantidad es invalida
      --IF instr(lc_cadena, ',', 1, 26) > 0 THEN
      --IF instr(lc_cadena, ',', 1, 29) > 0 THEN  -->  11/06/2014
      	IF instr(lc_cadena, ',', 1, 30) > 0 THEN   --rp -->  
         p_error := 'Linea ' || ln_cont || 'tiene mayor cantidad de columnas';
         RAISE e_line_more_data;
      --ELSIF instr(lc_cadena, ',', 1, 25) = 0 THEN
      --ELSIF instr(lc_cadena, ',', 1, 28) = 0 THEN -->  11/06/2014
      	ELSIF instr(lc_cadena, ',', 1, 29) = 0 THEN  --rp-->  
         p_error := 'Linea ' || ln_cont || 'tiene menor cantidad de columnas';
         RAISE e_line_few_data;
      ELSE
      	 
         -- empieza llenado de tabla a cargar
         lc_cadena_aux := ltrim(rtrim(lc_cadena));
-- saca ruc
         v_dat_car := 'obtener ruc';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
        
         IF v_posi = 1 OR v_cad_inte IS NULL THEN
             v_error := 'RUC se encuentra vacio';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_doc_id := v_cad_inte;
             ----------- check proveedor -------------> 18/05/2014
         		/*IF (v_doc_id=tmp_prv) THEN
         				SELECT csc_load_trx_s.CURRVAL INTO v_csc_prv FROM DUAL;
         		ELSE
         				SELECT csc_load_trx_s.NEXTVAL INTO v_csc_prv FROM DUAL;
         		END IF;
         				tmp_prv:=v_doc_id;*/
         ----------- check proveedor -------------> 18/05/2014
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el RUC de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca origen
         v_dat_car := 'obtener origen';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         IF v_posi = 1 THEN
             v_error := 'Origen se encuentra vacio';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_transac_source := v_cad_inte;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el Origen de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca serie -->  11/06/2014
         /*v_dat_car := 'obtener serie';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         IF v_posi = 1 THEN
             v_error := 'Serie se encuentra vacio';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_transac_Serial := v_cad_inte;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener la serie de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));*/ -->  11/06/2014
-- saca número de factura ó correlativo
         /*v_dat_car := 'obtener numero de factura';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
    --     IF v_posi = 1 THEN
    --             v_error := 'Número de factura se encuentra vacio';
    ---         RAISE e_conversion;
    --     END IF;
         BEGIN
            v_transac_number := v_cad_inte;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el número de factura de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));*/  -->  14/05/2014
         v_line := NULL;
--  13/05/2014
-- saca linea
         v_dat_car := 'obtener linea';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         --srw.message('666', 'OTHERS: ' || to_char(v_posi));  -->  jca
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         --srw.message('666', 'linea: ' || v_cad_inte);  -->  jca
         IF v_posi = 1 THEN
             v_error := 'Número de línea se encuentra vacio';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_line := v_cad_inte;
            
            v_check := v_line;
            ----------- checkcontrol  -------------> 06/11/2014
         		IF (v_check<>'1') THEN
         				SELECT csc_load_trx_s.CURRVAL INTO v_csc_prv FROM DUAL;
         		ELSE
         				SELECT csc_load_trx_s.NEXTVAL INTO v_csc_prv FROM DUAL;
         		END IF;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el numero de linea de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
--  13/05/2014
-- saca fecha
         v_dat_car := 'obtener fecha';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         BEGIN
            IF v_posi = 1 THEN
                v_transac_date := NULL; 
            ELSE
                 v_transac_date := to_date(v_cad_inte, 'DD/MM/RRRR HH24:MI:SS');
            END IF;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el fecha de la transaccion de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca descripcion
         v_dat_car := 'obtener descripcion';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         IF v_posi = 1 THEN
             v_error := 'Descripción se encuentra vacía';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_transac_reference := v_cad_inte;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener la descripcion de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca divisa
         v_dat_car := 'obtener divisa';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         BEGIN
            IF v_posi = 1 THEN
                 v_transac_currency := NULL; 
            ELSE
                 v_transac_currency := upper(v_cad_inte);
            END IF;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener Moneda de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca tipo
         v_dat_car := 'obtener tipo';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         BEGIN
            IF v_posi = 1 THEN
                 v_transac_type := NULL; 
            ELSE
                 v_transac_type := v_cad_inte;
            END IF;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el tipo de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca fecha contable
         v_dat_car := 'obtener fecha contable';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         BEGIN
            IF v_posi = 1 THEN
                 v_acounting_date := NULL; 
            ELSE
                 v_acounting_date := to_date(v_cad_inte, 'DD/MM/RRRR HH24:MI:SS');
            END IF;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener la fecha contable de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca flujo caja
         v_dat_car := 'obtener flujo caja';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         BEGIN
            IF v_posi = 1 THEN
                 v_box_flow := NULL; 
            ELSE
                 v_box_flow := v_cad_inte;
            END IF;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el flujo caja de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca terminos de pago
         v_dat_car := 'obtener terminos de pago';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         BEGIN
            IF v_posi = 1 THEN
                 v_payment_terms := NULL; 
            ELSE
                 v_payment_terms := v_cad_inte;
            END IF;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener los terminos de pago de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca vendedor
         v_dat_car := 'obtener vendedor';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         BEGIN
            IF v_posi = 1 THEN
                 v_vendor_id := NULL; 
            ELSE
                 v_vendor_id := v_cad_inte;
            END IF;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el vendedor de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca cantidad
         v_dat_car := 'obtener cantidad';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         IF v_posi = 1 THEN
             v_error := 'No se ha registrado cantidad para la transacción';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_amount_product := v_cad_inte;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener la cantidad de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca precio unitario
         v_dat_car := 'obtener precio unitario';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         IF v_posi = 1 THEN
             v_error := 'No se ha registrado precio unitario para el producto';
             RAISE e_conversion;
         END IF;
         BEGIN
         	  IF :p_flag = 'NOTA DE CREDITO' THEN
            		v_unitary_price := v_cad_inte*-1; -->  09/11/2014
         	  ELSE
         	  	 	v_unitary_price := v_cad_inte;
         	  END IF;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el precio unitario de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca seg1
         v_dat_car := 'obtener segmento 1';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         IF v_posi = 1 THEN
             v_error := 'Error a sacar dato del segmento 1';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_segment1 := v_cad_inte;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el segmento 1 de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca seg2
         v_dat_car := 'obtener segmento 2';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         IF v_posi = 1 THEN
             v_error := 'Error a sacar dato del segmento 2';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_segment2 := v_cad_inte;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el segmento 2 de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca seg3
         v_dat_car := 'obtener segmento 3';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         IF v_posi = 1 THEN
             v_error := 'Error a sacar dato del segmento 3';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_segment3 := v_cad_inte;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el segmento 3 de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca seg4
         v_dat_car := 'obtener segmento 4';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         IF v_posi = 1 THEN
             v_error := 'Error a sacar dato del segmento 4';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_segment4 := v_cad_inte;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el segmento 4 de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca seg5
         v_dat_car := 'obtener segmento 5';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         IF v_posi = 1 THEN
             v_error := 'Error a sacar dato del segmento 5';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_segment5 := v_cad_inte;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el segmento 5 de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca seg6
         v_dat_car := 'obtener segmento 6';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         IF v_posi = 1 THEN
             v_error := 'Error a sacar dato del segmento 6';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_segment6 := v_cad_inte;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el segmento 6 de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca seg7
         v_dat_car := 'obtener segmento 7';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         IF v_posi = 1 THEN
             v_error := 'Error a sacar dato del segmento 7';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_segment7 := v_cad_inte;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el segmento 7 de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca seg8
         v_dat_car := 'obtener segmento 8';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         IF v_posi = 1 THEN
             v_error := 'Error a sacar dato del segmento 8';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_segment8 := v_cad_inte;
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener el segmento 8 de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca impuestos
         v_dat_car := 'obtener impuestos';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         IF v_posi = 1 THEN
             v_error := 'Error a sacar dato de impuestos';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_tax_code := upper(v_cad_inte);
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error a sacar dato de impuestos';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca categoria Impuesto  -- 11/06/2014
         /*v_dat_car := 'obtener categoria impuestos';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         IF v_posi = 1 THEN
             v_error := 'Error al sacar categoria impuestos';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_attribute_category := upper(v_cad_inte);
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error a sacar categoria impuestos';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));*/
       
-- Cabecera descripcion ó referencia
         v_dat_car := 'obtener glosa de la factura';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
--         srw.message('111','Cad Glosa : '|| v_cad_inte);
         /*
         IF v_posi = 1 THEN
             v_error := 'Error al obtener glosa de la factura';
             RAISE e_conversion;
         END IF;
         */
         BEGIN
            v_header_description := upper(v_cad_inte);
         --   srw.message('111','Attribute_category : '|| v_attribute_category || ' num regi: ' || ln_cont);
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener glosa de la factura';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
-- saca instrucciones especiales --  11/06/2014
         v_dat_car := 'obtener instrucciones especiales';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         IF v_posi = 1 THEN
             v_error := 'Error al sacar instrucciones especiales';
             RAISE e_conversion;
         END IF;
         BEGIN
            v_ins_esp := upper(v_cad_inte);
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error a sacar categoria impuestos';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));           
-- Comentarios de la factura (puede ir en blanco)
         v_dat_car := 'obtener comentarios de la factura';
				 -->  27/08/2013
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         --> srw.message('112','comentarios : '|| v_cad_inte);
				 -->
         BEGIN
            --v_comments := (rtrim(lc_cadena_aux));
            v_comments := (rtrim(v_cad_inte));
            
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener comentarios de la factura';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));  -->  27/08/2013
         ----------------------------------------------------- para las NC  --------------------------------------------
         -- motivo de emision (puede ir en blanco)
         v_dat_car := 'obtener motivo de emision de la ND';
				 -->  27/08/2014
         v_posi := instr(lc_cadena_aux, ',', 1, 1);
         v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         --> srw.message('112','comentarios : '|| v_cad_inte);
				 -->
         BEGIN
            --v_comments := (rtrim(lc_cadena_aux));
            v_motivo := (rtrim(v_cad_inte));
            
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener comentarios de la factura';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));  -->  27/08/2013
         --IF v_mon_fac<0 THEN
         	-->
         	v_dat_car := 'obtener tipo de documento relacionado';
          v_posi := instr(lc_cadena_aux, ',', 1, 1);
          v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
          --srw.message('112','tipo de documento relacionado : '|| v_cad_inte);
         		IF v_posi = 1 THEN
             v_error := 'Error al obtener tipo de documento relacionado';
             RAISE e_conversion;
            END IF;
         BEGIN
            v_tip_doc_rel := lpad(v_cad_inte,2,'0');
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener tipo de documento relacionado de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
         -----------------------------------------------------------
         -->
         v_dat_car := 'obtener fecha del documento relacionado';
          v_posi := instr(lc_cadena_aux, ',', 1, 1);
          v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
          -- srw.message('113','fecha de documento relacionado : '|| v_cad_inte);
         		IF v_posi = 1 THEN
             v_error := 'Error al obtener fecha del documento relacionado';
             RAISE e_conversion;
            END IF;
         BEGIN
            --v_fec_doc_rel := to_date(v_cad_inte,'dd/mm/rrrr');
            v_fec_doc_rel := v_cad_inte||' 00:00:00';
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener fecha del documento relacionado de la cadena';
                RAISE e_conversion;
         END;
        
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
         ------------------------------------------------------------------------------------------------
         -->
         v_dat_car := 'obtener numero del documento relacionado';
         v_posi := instr(lc_cadena_aux, ',', 1, 1);--rp
          v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1)); --rp
        -- v_cad_inte := ltrim(rtrim(lc_cadena_aux)); --rp comentado --> esto va cuando es el final de la cadena
         --srw.message('113','numero de documento relacionado : '|| v_cad_inte);
         --v_posi := instr(lc_cadena_aux, ',', 1, 1);   --> esto no va cuando es final de la cadena
         --v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         
         IF v_posi = 1 THEN
             v_error := 'Error al sacar numero del documento relacionado';
             RAISE e_conversion;
         END IF;
         BEGIN
         	  --v_num_doc_rel := v_cad_inte;  -- 22/05/2013
            v_num_doc_rel := replace(v_cad_inte,chr(13));  --> 22/05/2013 elimina los enter en el dato
            --srw.message('200',v_cod_imp);-- jca
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener numero del documento relacionado de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
         -----------------------------------------------------------------------------------------------
          v_dat_car := 'obtener codigo producto sunat';
         v_cad_inte := ltrim(rtrim(lc_cadena_aux)); --> esto va cuando es el final de la cadena
         --srw.message('113','numero de documento relacionado : '|| v_cad_inte);
         --v_posi := instr(lc_cadena_aux, ',', 1, 1);   --> esto no va cuando es final de la cadena
         --v_cad_inte := rtrim(substr(lc_cadena_aux, 1, v_posi - 1));
         
         IF v_posi = 1 THEN
             v_error := 'Error al sacar codigo producto sunat';
             RAISE e_conversion;
         END IF;
         BEGIN
         	  --v_num_doc_rel := v_cad_inte;  -- 22/05/2013
            v_cod_prod_sunat  := replace(v_cad_inte,chr(13));  --> 22/05/2013 elimina los enter en el dato
            --srw.message('200',v_cod_imp);-- jca
         EXCEPTION
             WHEN OTHERS THEN
                v_error := 'Error al obtener codigo producto sunat de la cadena';
                RAISE e_conversion;
         END;
         lc_cadena_aux := ltrim(rtrim(substr(lc_cadena_aux, v_posi + 1, length(lc_cadena_aux))));
         -- Llena la tabla temporal
         v_dat_car := 'Insertar intersf.sy_ar_pe_load_accounts';
         
          INSERT
           INTO intersf.sy_ar_pe_load_accounts
                                      (num_regi,
                                       doc_id,
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
                                       header_description,
                                       INTERNAL_NOTES, --> 11/06/2014
                                       comments,
                                       ----------------->  27/08/2013 
                                       header_attribute13, 
                                       header_attribute12,
                        							 header_attribute11,
                        							 motivo  --> 28/08/2014
                                       ,codProductoSunat)
                                VALUES(ln_cont,
                                       v_doc_id,
                                       v_transac_source,
                                       v_transac_source,--v_transac_serial, -->  11/06/2014
                                       v_csc_prv,--v_transac_number, --> 18/05/2014
                                       v_line,
                                       v_transac_date,
                                       v_transac_reference,
                                       v_transac_currency,
                                       v_transac_type,
                                       v_acounting_date,
                                       v_box_flow,
                                       v_payment_terms,
                                       v_vendor_id,
                                       v_amount_product,
                                       v_unitary_price,
                                       v_segment1,
                                       v_segment2,
                                       v_segment3,
                                       v_segment4,
                                       v_segment5,
                                       v_segment6,
                                       v_segment7,
                                       v_segment8,
                                       v_tax_code,
                                       decode(v_tax_code,'S','002','N','004','E','007',NULL),--v_attribute_category, --> 11/06/2014
                                       v_header_description,
                                       v_ins_esp, -->  11/06/2014
                                       v_comments,
                                       -----------------> 27/08/2013
                                       v_tip_doc_rel,
                                       v_num_doc_rel,
                                       v_fec_doc_rel,
                                       v_motivo --> 28/08/2014
                                      , v_cod_prod_sunat);
       
                                  
      END IF;
   END LOOP;
   
   --text_io.fclose(lv_out_file); -- se cierra el archivo /* para report */
   utl_file.fclose(lv_out_file);  -- se cierra el archivo /* para finacial*/
   p_error := NULL;
   p_regi := ln_cont;
EXCEPTION 
   WHEN e_conversion THEN
      --text_io.fclose(lv_out_file); -- se cierra el archivo /* para report */
      utl_file.fclose(lv_out_file);  -- se cierra el archivo /* para finacial*/
      srw.message('900','An error when conversion data, line:' || ln_cont);
      p_error := 'Linea : ' || ln_cont || ' ' || v_error;
      srw.message('900',p_error);
      srw.message('900',lc_cadena);
      ln_cont := NULL;
   WHEN e_line_few_data THEN
      --text_io.fclose(lv_out_file); -- se cierra el archivo /* para report */
      utl_file.fclose(lv_out_file);  -- se cierra el archivo /* para finacial*/
      p_error := 'Line with less columns, line: ' || ln_cont;
      srw.message('900', 'e_line_few_data: ' || p_error);
      srw.message('900', 'e_line_few_data: ' || lc_cadena);
      ln_cont := NULL;
   WHEN e_line_more_data THEN
      --text_io.fclose(lv_out_file); -- se cierra el archivo /* para report */
      utl_file.fclose(lv_out_file);  -- se cierra el archivo /* para finacial*/
      p_error := 'Line with more columns, line: ' || ln_cont;
      srw.message('900', 'e_line_more_data: ' || p_error);
      srw.message('900', 'e_line_more_data: ' || lc_cadena);
      ln_cont := NULL;
   WHEN OTHERS THEN
      --Text_IO.Fclose(lv_out_file); -- se cierra el archivo /* para Report */
      utl_file.fclose(lv_out_file);  -- se cierra el archivo /* para finacial*/
      p_error := v_dat_car || '- line: ' || ln_cont || ' Failure - '|| sqlerrm;
      srw.message('900', 'OTHERS: ' || p_error);
      srw.message('900', 'OTHERS: ' || lc_cadena);
      :cp_cont_regis_act := ln_cont;
END p_load_file_nd;
