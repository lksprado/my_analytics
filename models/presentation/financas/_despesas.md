# Gastos

## Objetivo

Descrever gastos pessoais e orientar a interpretação da rotina de Lucas e Jéssica para elaboração de relatórios.

## Categorias de Gastos

### Mercado

**Significa**: gastos com alimentos e bebidas

**Entra**: supermercado, feira, marmitas fit, açougue

**Não entra**: refeição fora de casa ou delivery (→ `role`), farmácia (→ `saude`), utensílios, móveis e eletrodomésticos (→ `diversos`).

**Natureza**: estável, essencial. Picos indicam concentração deliberada em itens de maior valor agregado (ex. bebidas alcóolicas mais refinadas).

---

### Diversos

**Significa**: Gastos pontuais sem recorrência

**Entra**: vestuário e calçado, presentes, eletrônicos, acessórios pessoais, objetos domésticos, imprevistos, hobbies, salão de beleza e o que não couber nas demais.

**Não entra**: nada que tenha categoria própria.

**Natureza**: variável e não essencial. Flags `fl_data_especial` e `fl_mes_especial` explicam picos e variações.

---

### Assinaturas

**Significa**: Consumo de serviços

**Entra**: streaming de vídeo e música, nuvem de armazenamento, licenças de software, telefonia móvel, academia, jornais, planos de IA.

**Não entra**: internet fixa (→ `apartamento`), plano de saúde (→ `saude`), mensalidade de curso (→ `educacao`).

**Natureza**: estável e relativamente essencial. Corte significa reduzir alcance de conteúdos e prejuízo no padrão de vida.

---

### Role

**Significa**: lazer e consumo fora de casa.

**Entra**: bares e restaurantes, delivery e aplicativos de comida, cafés, cinema, shows, eventos, viagens (hospedagem, aluguel de veículo, passeios), compras de mercado só para eventos e hobbies.

**Não entra**: transporte para chegar ao rolê (→ `transporte`), exceto aluguel de veículo.

**Natureza**: variável e não essencial. Flags `fl_data_especial` e `fl_mes_especial` explicam picos.

---

### Transporte

**Significa**: Despesas com carro e deslocamento.

**Entra**: combustível, aplicativos de transporte, transporte público, estacionamento, pedágio, manutenção e revisão, seguro, IPVA e licenciamento.

**Não entra**: viagem de lazer com hospedagem (→ `role`).

**Natureza**: estável e essencial.

---

### Apartamento

**Significa**: Despesas com moradia e manutenção.

**Entra**: condomínio, IPTU, energia elétrica, internet fixa, móveis, reformas e reparos.

**Não entra**: produtos de limpeza e consumo da casa (→ `mercado`).

**Natureza**: estável e essencial. Picos podem ser explicados em `_fatos_relevantes.md`.

---

### Saúde

**Significa**: saúde física e mental.

**Entra**: plano de saúde, consultas, exames, procedimentos, odontologia, terapia, farmácia e medicamentos.

**Não entra**: academia (→ `assinaturas`).

**Natureza**: estável e essencial. Picos podem ser explicados em `_fatos_relevantes.md`.

---

### Educacao

**Significa** — Investimento em capital humano para formação e desenvolvimento.

**Entra**: cursos, graduação e pós-graduação, certificações, livros, material didático e plataformas de ensino.

**Não entra**: plataforma de conteúdo genérico (→ `assinaturas`).

**Natureza**: variável e não essencial.
