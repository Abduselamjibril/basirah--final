import React from 'react';
import ContentEditorPage from '../../components/ContentEditorPage';

const AboutUsPage = () => {
  return (
    <ContentEditorPage
      pageTitle="About Us"
      pageSubtitle="Manage the content for the 'About Us' page in the mobile app."
      endpoint="about-us"
    />
  );
};

export default AboutUsPage;