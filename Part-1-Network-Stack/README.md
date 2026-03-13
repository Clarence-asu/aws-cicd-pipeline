# Part 1 — Network Stack

I built this VPC template as part of my [AWS EKS Infrastructure project](https://github.com/Clarence-asu/AWS-EKS-Project) and carried it over to this one. No reason to rebuild it from scratch when the foundation already works. This is the first stack that gets deployed and everything else in the project sits on top of it.

---

## What Gets Built

A three tier VPC across two Availability Zones — public, app, and DB subnets each with their own routing logic.

- **VPC** `10.0.0.0/16`
- **Internet Gateway** attached to the public subnets
- **NAT Gateway** sitting in Public Subnet A so private resources can reach out without being reachable from the outside
- **Public Subnets** `10.0.1.0/24` and `10.0.2.0/24`
- **App Subnets** `10.0.11.0/24` and `10.0.12.0/24` — EKS cluster and worker nodes live here
- **DB Subnets** `10.0.21.0/24` and `10.0.22.0/24` — isolated, no route out
- **Route Tables** one per tier so traffic goes where it should and nowhere else

---

## Subnet Breakdown

| Subnet | CIDR | AZ | Routing |
|--------|------|----|---------|
| Public A | 10.0.1.0/24 | us-east-1a | IGW |
| Public B | 10.0.2.0/24 | us-east-1b | IGW |
| App A | 10.0.11.0/24 | us-east-1a | NAT only |
| App B | 10.0.12.0/24 | us-east-1b | NAT only |
| DB A | 10.0.21.0/24 | us-east-1a | Local only |
| DB B | 10.0.22.0/24 | us-east-1b | Local only |

---

## Two AZs

Spreading across two AZs means if one goes down the workload keeps running in the other. It's the baseline for anything that needs to stay up.

---

## Stack Exports

The template exports everything the downstream stacks need so nothing gets hardcoded.

| Export | Description |
|--------|-------------|
| `mtier:VpcId` | VPC ID |
| `mtier:VpcCidr` | VPC CIDR block |
| `mtier:PublicSubnetA` | Public Subnet A |
| `mtier:PublicSubnetB` | Public Subnet B |
| `mtier:AppSubnetA` | App Subnet A |
| `mtier:AppSubnetB` | App Subnet B |
| `mtier:DBSubnetA` | DB Subnet A |
| `mtier:DBSubnetB` | DB Subnet B |
| `mtier:PrivateSubnets` | App subnets comma-delimited for EKS node groups |
| `mtier:NatGatewayId` | NAT Gateway ID |

---

## Deploy Order

This goes first. The EKS and worker node stacks both import values from here so they will fail if this isn't already deployed.

```
Part 1 - Network Stack         ← deploy first
Part 2 - EKS Cluster Stack     ← needs VpcId and PrivateSubnets
Part 3 - Worker Node Stack     ← needs PrivateSubnets
Part 4 - CI/CD Pipeline        ← builds on top of all of this
```

---

## Note on Reuse

Same template from the EKS project with no major changes. The exports were already set up to feed into other stacks so plugging it in here was straightforward. Writing reusable templates from the start is what makes this kind of thing easy later on.
