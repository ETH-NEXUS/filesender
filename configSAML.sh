#!/usr/bin/env bash

ENTITYID="$(xmllint --xpath 'string(/*[local-name()="EntityDescriptor"]/@entityID)' /tmp/idp-metadata.xml)"

SSO="$(xmllint --xpath 'string(//*[local-name()="IDPSSODescriptor"]/*[local-name()="SingleSignOnService" and contains(@Binding,"HTTP-Redirect")][1]/@Location)' /tmp/idp-metadata.xml)"

CERT="$(xmllint --xpath 'string((//*[local-name()="X509Certificate"])[1])' /tmp/idp-metadata.xml | tr -d '\n\r ')"

cat > /opt/filesender/simplesaml/metadata/saml20-idp-remote.php <<EOF
<?php
\$metadata['$ENTITYID'] = [
  'SingleSignOnService' => [
    [
      'Binding' => 'urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect',
      'Location' => '$SSO',
    ],
  ],
  'certData' => '$CERT',
];
EOF

sed -i -e "s@'idp' => .*@'idp' => 'https://saml.example.com/entityid',@g" opt/filesender/simplesaml/config/authsources.php ; \