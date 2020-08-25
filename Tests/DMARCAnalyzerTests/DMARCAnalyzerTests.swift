//
//  File.swift
//  
//
//  Created by Andrew J Wagner on 8/25/20.
//

import XCTest
@testable import DMARCAnalyzer

class DMARCAnalyzerTests: XCTestCase {
    func testGood() throws {
        let report = """
            <?xml version="1.0" encoding="UTF-8" ?>
            <feedback>
              <report_metadata>
                <org_name>google.com</org_name>
                <email>noreply-dmarc-support@google.com</email>
                <extra_contact_info>https://support.google.com/a/answer/2466580</extra_contact_info>
                <report_id>344784217811437857</report_id>
                <date_range>
                  <begin>1598227200</begin>
                  <end>1598313599</end>
                </date_range>
              </report_metadata>
              <policy_published>
                <domain>example.com</domain>
                <adkim>r</adkim>
                <aspf>r</aspf>
                <p>reject</p>
                <sp>reject</sp>
                <pct>100</pct>
              </policy_published>
              <record>
                <row>
                  <source_ip>2001:db8::1:0</source_ip>
                  <count>4</count>
                  <policy_evaluated>
                    <disposition>none</disposition>
                    <dkim>pass</dkim>
                    <spf>pass</spf>
                  </policy_evaluated>
                </row>
                <identifiers>
                  <header_from>example.com</header_from>
                </identifiers>
                <auth_results>
                  <dkim>
                    <domain>example.com</domain>
                    <result>pass</result>
                    <selector>mail</selector>
                  </dkim>
                  <spf>
                    <domain>example.com</domain>
                    <result>pass</result>
                  </spf>
                </auth_results>
              </record>
              <record>
                <row>
                  <source_ip>192.168.1.35</source_ip>
                  <count>4</count>
                  <policy_evaluated>
                    <disposition>none</disposition>
                    <dkim>pass</dkim>
                    <spf>pass</spf>
                  </policy_evaluated>
                </row>
                <identifiers>
                  <header_from>example.com</header_from>
                </identifiers>
                <auth_results>
                  <dkim>
                    <domain>example.com</domain>
                    <result>pass</result>
                    <selector>mail</selector>
                  </dkim>
                  <spf>
                    <domain>example.com</domain>
                    <result>pass</result>
                  </spf>
                </auth_results>
              </record>
              <record>
                <row>
                  <source_ip>192.168.1.36</source_ip>
                  <count>4</count>
                  <policy_evaluated>
                    <disposition>none</disposition>
                    <dkim>pass</dkim>
                    <spf>pass</spf>
                  </policy_evaluated>
                </row>
                <identifiers>
                  <header_from>example.com</header_from>
                </identifiers>
                <auth_results>
                  <dkim>
                    <domain>example.com</domain>
                    <result>pass</result>
                    <selector>mail</selector>
                  </dkim>
                  <spf>
                    <domain>example.com</domain>
                    <result>pass</result>
                  </spf>
                </auth_results>
              </record>
              <record>
                <row>
                  <source_ip>192.168.1.100</source_ip>
                  <count>4</count>
                  <policy_evaluated>
                    <disposition>none</disposition>
                    <dkim>fail</dkim>
                    <spf>fail</spf>
                  </policy_evaluated>
                </row>
                <identifiers>
                  <header_from>example.com</header_from>
                </identifiers>
                <auth_results>
                  <dkim>
                    <domain>example.com</domain>
                    <result>fail</result>
                    <selector>mail</selector>
                  </dkim>
                  <spf>
                    <domain>example.com</domain>
                    <result>fail</result>
                  </spf>
                </auth_results>
              </record>
              <record>
                <row>
                  <source_ip>192.168.1.50</source_ip>
                  <count>4</count>
                  <policy_evaluated>
                    <disposition>none</disposition>
                    <dkim>pass</dkim>
                    <spf>fail</spf>
                  </policy_evaluated>
                </row>
                <identifiers>
                  <header_from>example.com</header_from>
                </identifiers>
                <auth_results>
                  <dkim>
                    <domain>example.com</domain>
                    <result>pass</result>
                    <selector>mail</selector>
                  </dkim>
                  <spf>
                    <domain>example.com</domain>
                    <result>fail</result>
                  </spf>
                </auth_results>
              </record>
            </feedback>
            """.data(using: .utf8)!

        let options = """
            {
                "sourceEmail": "dmarc-analyzer@example.com",
                "problemEmail": "dmarc@example.com",
                "approvedServers": [
                    "192.168.1.35",
                    "2001:0db8::0001:0000"
                ],
                "domainSpecificServers": {
                    "example.com": ["192.168.1.36"]
                }
            }
            """.data(using: .utf8)!

        let analyzer = try DMARCAnalyzer(domain: "example.com", report: report, options: options)
        switch try analyzer.analyze() {
        case .good(let orgName):
            XCTAssertEqual(orgName, "google.com")
        case .bad:
            XCTFail()
        }
    }

    func testBad() throws {
        let report = """
            <?xml version="1.0" encoding="UTF-8" ?>
            <feedback>
              <report_metadata>
                <org_name>google.com</org_name>
                <email>noreply-dmarc-support@google.com</email>
                <extra_contact_info>https://support.google.com/a/answer/2466580</extra_contact_info>
                <report_id>344784217811437857</report_id>
                <date_range>
                  <begin>1598227200</begin>
                  <end>1598313599</end>
                </date_range>
              </report_metadata>
              <policy_published>
                <domain>example.com</domain>
                <adkim>r</adkim>
                <aspf>r</aspf>
                <p>reject</p>
                <sp>reject</sp>
                <pct>100</pct>
              </policy_published>
              <record>
                <row>
                  <source_ip>2001:db8::1:0</source_ip>
                  <count>4</count>
                  <policy_evaluated>
                    <disposition>none</disposition>
                    <dkim>fail</dkim>
                    <spf>pass</spf>
                  </policy_evaluated>
                </row>
                <identifiers>
                  <header_from>example.com</header_from>
                </identifiers>
                <auth_results>
                  <dkim>
                    <domain>example.com</domain>
                    <result>fail</result>
                    <selector>mail</selector>
                  </dkim>
                  <spf>
                    <domain>example.com</domain>
                    <result>pass</result>
                  </spf>
                </auth_results>
              </record>
              <record>
                <row>
                  <source_ip>192.168.1.35</source_ip>
                  <count>4</count>
                  <policy_evaluated>
                    <disposition>none</disposition>
                    <dkim>pass</dkim>
                    <spf>fail</spf>
                  </policy_evaluated>
                </row>
                <identifiers>
                  <header_from>example.com</header_from>
                </identifiers>
                <auth_results>
                  <dkim>
                    <domain>example.com</domain>
                    <result>pass</result>
                    <selector>mail</selector>
                  </dkim>
                  <spf>
                    <domain>example.com</domain>
                    <result>fail</result>
                  </spf>
                </auth_results>
              </record>
              <record>
                <row>
                  <source_ip>192.168.1.36</source_ip>
                  <count>4</count>
                  <policy_evaluated>
                    <disposition>none</disposition>
                    <dkim>fail</dkim>
                    <spf>fail</spf>
                  </policy_evaluated>
                </row>
                <identifiers>
                  <header_from>example.com</header_from>
                </identifiers>
                <auth_results>
                  <dkim>
                    <domain>example.com</domain>
                    <result>fail</result>
                    <selector>mail</selector>
                  </dkim>
                  <spf>
                    <domain>example.com</domain>
                    <result>fail</result>
                  </spf>
                </auth_results>
              </record>
              <record>
                <row>
                  <source_ip>192.168.1.100</source_ip>
                  <count>4</count>
                  <policy_evaluated>
                    <disposition>none</disposition>
                    <dkim>fail</dkim>
                    <spf>pass</spf>
                  </policy_evaluated>
                </row>
                <identifiers>
                  <header_from>example.com</header_from>
                </identifiers>
                <auth_results>
                  <dkim>
                    <domain>example.com</domain>
                    <result>fail</result>
                    <selector>mail</selector>
                  </dkim>
                  <spf>
                    <domain>example.com</domain>
                    <result>pass</result>
                  </spf>
                </auth_results>
              </record>
              <record>
                <row>
                  <source_ip>192.168.1.50</source_ip>
                  <count>4</count>
                  <policy_evaluated>
                    <disposition>none</disposition>
                    <dkim>pass</dkim>
                    <spf>pass</spf>
                  </policy_evaluated>
                </row>
                <identifiers>
                  <header_from>example.com</header_from>
                </identifiers>
                <auth_results>
                  <dkim>
                    <domain>example.com</domain>
                    <result>pass</result>
                    <selector>mail</selector>
                  </dkim>
                  <spf>
                    <domain>example.com</domain>
                    <result>pass</result>
                  </spf>
                </auth_results>
              </record>
            </feedback>
            """.data(using: .utf8)!

        let options = """
            {
                "sourceEmail": "dmarc-analyzer@example.com",
                "problemEmail": "dmarc@example.com",
                "approvedServers": [
                    "192.168.1.35",
                    "2001:0db8::0001:0000"
                ],
                "domainSpecificServers": {
                    "example.com": ["192.168.1.36"]
                }
            }
            """.data(using: .utf8)!

        let analyzer = try DMARCAnalyzer(domain: "example.com", report: report, options: options)
        switch try analyzer.analyze() {
        case .good:
            XCTFail()
        case let .bad(orgName, failures):
            XCTAssertEqual(orgName, "google.com")
            XCTAssertEqual(failures.count, 5)
            guard failures.count == 5 else {
                return
            }
            XCTAssertEqual(failures[0].sourceIp, "2001:db8::1:0")
            XCTAssertEqual(failures[0].reason, .approvedServerFailedDKIM)

            XCTAssertEqual(failures[1].sourceIp, "192.168.1.35")
            XCTAssertEqual(failures[1].reason, .approvedServerFailedSPF)

            XCTAssertEqual(failures[2].sourceIp, "192.168.1.36")
            XCTAssertEqual(failures[2].reason, .approvedServerFailedFully)

            XCTAssertEqual(failures[3].sourceIp, "192.168.1.100")
            XCTAssertEqual(failures[3].reason, .unapprovedServerPassedSPF)

            XCTAssertEqual(failures[4].sourceIp, "192.168.1.50")
            XCTAssertEqual(failures[4].reason, .unapprovedServerPassedFully)
        }
    }
}
