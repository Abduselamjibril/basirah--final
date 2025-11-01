import React from 'react';
import ContentEditorPage from '../../components/ContentEditorPage';

const TermsPage = () => {
  return (
    <ContentEditorPage
      pageTitle="Terms & Agreement"
      pageSubtitle="Manage the content for the 'Terms & Agreement' page in the mobile app."
      endpoint="terms-and-agreement"
    />
  );
};

export default TermsPage;