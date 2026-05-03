---
title: "📚 TP Terraform"
layout: home
---

Bienvenue dans les travaux pratiques Terraform.

---

## 🧪 Liste des TP

{% for tp in site.tp %}
- [{{ tp.title }}]({{ tp.url }})
{% endfor %}