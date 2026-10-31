import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const Color primary = Color(0xFF0753B7);
  static const Color background = Color(0xFFF5F8FD);
  static const Color bodyColor = Color(0xFF475569);

  static const List<Map<String, String>> sections = [
    {
      'title': '1. About This Policy',
      'body':
          'GODIGITAL provides business, employee, HRMS, attendance, '
          'communication and client-management services. This policy '
          'explains how personal information is collected, processed, '
          'stored and shared. Organizations using the Service may '
          'determine how their employment and business records are managed.',
    },
    {
      'title': '2. Information We Collect',
      'body':
          'Depending on enabled features, the Service may process names, '
          'email addresses, mobile numbers, employee identifiers, roles, '
          'profile photographs, attendance, leave records, payroll details, '
          'location information, tasks, client records, chat messages, '
          'attachments, authorized client credentials, device tokens and '
          'account session information.',
    },
    {
      'title': '3. How Information Is Used',
      'body':
          'Information is used to authenticate users, manage access, '
          'record attendance, support HR and payroll functions, coordinate '
          'work, manage client operations, provide communications and '
          'notifications, maintain security and fulfil applicable legal '
          'and contractual requirements.',
    },
    {
      'title': '4. Location and Device Permissions',
      'body':
          'Location-dependent features may use GPS coordinates, accuracy '
          'and capture times for attendance and field-work purposes. '
          'During an employee-started tracking session, periodic '
          'locations may be processed. Authorized administrators may '
          'review relevant records. Users can manage location and '
          'notification permissions through their device or browser.',
    },
    {
      'title': '5. Information Sharing',
      'body':
          'Information may be accessible to authorized organizational '
          'administrators, managers and employees according to assigned '
          'permissions. Hosting, infrastructure and notification '
          'providers may process information needed to deliver services. '
          'Where configured, mapping services may process coordinates. '
          'Disclosure may also occur when required by applicable law. '
          'The Service does not sell personal information for advertising.',
    },
    {
      'title': '6. Messages and Uploaded Files',
      'body':
          'Messages and attachments are stored and delivered through '
          'the Service. Chat is not end-to-end encrypted in the reviewed '
          'project. The current backend may serve files through direct '
          '/uploads URLs, which can be accessible to someone who knows '
          'the URL. Do not upload sensitive documents until appropriate '
          'access restrictions have been implemented and verified.',
    },
    {
      'title': '7. Client Credentials',
      'body':
          'Authorized users may enter and manage client usernames, '
          'passwords, account links and related business information. '
          'Only credentials approved for organizational use should be '
          'stored. Credential-storage protections must be verified '
          'against the deployed system.',
    },
    {
      'title': '8. Data Retention',
      'body':
          'Information may be retained for operational, employment, '
          'accounting and legal purposes. Retention periods vary by '
          'record type and organization. Deletion may be subject to '
          'legal obligations, security needs and backup procedures.',
    },
    {
      'title': '9. Data Security',
      'body':
          'The Service uses authentication and role-based access '
          'mechanisms. GODIGITAL aims to maintain appropriate '
          'organizational and technical security safeguards. '
          'However, no electronic system can guarantee absolute security.',
    },
    {
      'title': '10. Your Rights and Requests',
      'body':
          'Subject to applicable law, users may request access, '
          'correction or deletion of their information. Employees '
          'should contact their organization administrator about '
          'employment records. Privacy requests can also be sent '
          'to godigitalclick@gmail.com. Identity verification and '
          'lawful retention requirements may apply.',
    },
    {
      'title': '11. Children and Policy Changes',
      'body':
          'The Service is designed for organizational workforce and '
          'business use and is not intended for children. This policy '
          'may be updated as services, technical practices or legal '
          'requirements change. Updated versions will show a revised date.',
    },
    {
      'title': '12. Contact Us',
      'body':
          'Company: GODIGITAL\n'
          'Privacy email: godigitalclick@gmail.com\n'
          'Website: https://godigitalindia.co',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF172B4D),
        elevation: 0,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 600;

          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: mobile ? 16 : 32,
              vertical: 20,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.all(mobile ? 22 : 34),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF063A89), primary],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.privacy_tip_outlined,
                            size: 34,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'GODIGITAL',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: mobile ? 25 : 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            'Privacy Policy',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Last updated: 31 October 2026',
                            style: TextStyle(color: Color(0xFFDCEAFF)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final section in sections)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Container(
                          padding: EdgeInsets.all(mobile ? 18 : 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: const Color(0xFFE5EBF3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                section['title']!,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF172B4D),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SelectableText(
                                section['body']!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.7,
                                  color: bodyColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        '© 2026 GODIGITAL. All rights reserved.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
