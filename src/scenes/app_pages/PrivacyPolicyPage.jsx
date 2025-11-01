import React from 'react';
import ContentEditorPage from '../../components/ContentEditorPage';

const PrivacyPolicyPage = () => {
  return (
    <ContentEditorPage
      pageTitle="Privacy Policy"
      pageSubtitle="Manage the content for the 'Privacy Policy' page in the mobile app."
      endpoint="privacy-policy"
    />
  );
};

export default PrivacyPolicyPage;