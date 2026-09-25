\getenv admin_password SG_ADMIN_PASSWORD
\if :{?admin_password}
\else
\echo 'Set SG_ADMIN_PASSWORD to a non-empty administrator password before running this script.'
\quit 3
\endif
\if :{?admin_password}
SELECT length(:'admin_password') >= 12 AS password_is_long_enough \gset
\if :password_is_long_enough
\else
\echo 'The administrator password must be at least 12 characters.'
\quit 3
\endif
\endif

\prompt 'NIT: ' company_nit
\prompt 'Razón social: ' company_name
\prompt 'Clase de riesgo ARL (1-5): ' risk_class
\prompt 'Número de trabajadores: ' employee_count
\prompt 'Correo del administrador: ' admin_email
\prompt 'Nombre del administrador: ' admin_name

SELECT auth.alta_empresa(
  :'company_nit',
  :'company_name',
  :'risk_class'::smallint,
  :'employee_count'::int,
  :'admin_email',
  :'admin_name',
  :'admin_password'
);
