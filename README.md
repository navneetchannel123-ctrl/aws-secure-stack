**AWS Secure-Stack: Modular Multi-AZ Infrastructure**

A production-grade cloud environment provisioned using a modular Terraform framework. This architecture is designed for high-availability (HA) and implements a Zero-Trust security model at the network layer.

---

**Architecture Design**

![AWS High-Availability & Zero-Trust Infrastructure Blueprint](./docs/aws-ha-zerotrust-architecture.png)

**Core Design Principles**

* **Regional Failover:** Resources are distributed across `us-east-1a` and `us-east-1b`. This ensures 99.99% availability; if one AWS data center experiences an outage, the Auto Scaling Group (ASG) maintains service continuity.
* **Modular Decoupling:** Infrastructure logic is isolated in `/modules/web_stack`. This allows the core engine to be reused across different environments while the root module handles environment-specific variables like CIDR blocks and IP filtering.

---

**Security Implementation**

**Ingress Filtering & Security Group Chaining**

To mitigate direct attack vectors, I implemented a tiered security model:
* **Edge Tier (ALB-SG):** Public-facing; strictly filtered for Port 80 ingress.
* **Application Tier (App-SG):** Isolated; strictly accepts traffic **ONLY** from the Application Load Balancer's Security Group ID.
* **Dynamic SSH Hardening:** Port 22 is restricted to the administrator's specific IP using a Terraform `http` data source, preventing unauthorized access attempts from external networks.

**Verification of Restricted Ingress:**
![Security Group Rules](./docs/Zero-Trust-Security-Groups.png)

**Edge Defense (AWS WAF)**

The Application Load Balancer is protected by a Web Application Firewall. I integrated **AWS Managed Rules (CommonRuleSet)** to inspect and drop malicious traffic (SQLi, XSS, and bot scrapers) before it reaches the compute layer.

---

**Project Structure**

* **main.tf** — Root Orchestrator (calls modules and dynamic data sources).
* **outputs.tf** — Final Endpoint URL exports for application access.
* **.gitignore** — Security file to prevent `.tfstate` and provider plugins from being committed.
* **/docs** — Technical documentation and architecture assets.
* **/modules/web_stack** — Reusable infrastructure engine containing core resource logic.

---

**Deployment Verification (Screenshots)**

**High Availability Instance Fleet**
Confirmation of the Auto Scaling Group successfully provisioning identical t2.micro nodes across multiple Availability Zones to ensure horizontal scalability.
![EC2 Instance Fleet](./docs/High-Availability-Fleet.png)

**Final Visual State (Custom Nginx Dashboard)**
The `user_data` script automates the full stack deployment: Nginx installation, system package management, and deployment of a custom-branded landing page.
![Landing Page](./docs/Project-Landing-Page.png)

**VPC Routing & Egress Logic**
Confirmation of the VPC routing table correctly mapping the `0.0.0.0/0` route to the Internet Gateway (IGW) for public egress.
![Routing Table](./docs/VPC-Internet-Egress.png)

---

**Deployment Guide**

To deploy this infrastructure in your own AWS environment, follow these steps:

 **Clone the Repository**
   ```bash
   git clone [https://github.com/navneetchannel123-ctrl/aws-secure-stack.git](https://github.com/navneetchannel123-ctrl/aws-secure-stack.git)
   cd aws-secure-stack