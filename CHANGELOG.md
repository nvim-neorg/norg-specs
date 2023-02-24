# Changelog

## [1.1.0](https://github.com/nvim-neorg/norg-specs/compare/v1.0.0...v1.1.0) (2023-02-24)


### Features

* **spec:** extend the abilities of the slide (`:`) ([d5c3127](https://github.com/nvim-neorg/norg-specs/commit/d5c3127f7e708f0aca0806f7eb26d24ccca161d8))

## 1.0.0 (2023-02-24)


### Features

* add `stdlib.norg`, start work on `0.1-semantics.norg` ([02edea0](https://github.com/nvim-neorg/norg-specs/commit/02edea0efde4a6204e94d782ece952a8cabc0724))
* add escape sequence character to level 1 ([dd4c01a](https://github.com/nvim-neorg/norg-specs/commit/dd4c01a3b69819f35c35940219d1259f509d8802))
* add extendable links ([8b64344](https://github.com/nvim-neorg/norg-specs/commit/8b64344d508ce8bffe45bf4ee3f997ea651ff341))
* add more attribute examples ([d8f3693](https://github.com/nvim-neorg/norg-specs/commit/d8f36931b0a151ccba2d5da45d5f9a49f746bb3d))
* add release-please ([85005a5](https://github.com/nvim-neorg/norg-specs/commit/85005a548cdc10a734d0ba0691e52158eee80f83))
* add scoping ([2e77031](https://github.com/nvim-neorg/norg-specs/commit/2e7703119c965b37045fe623a8359761e5946cda))
* add semantics document ([67a8bca](https://github.com/nvim-neorg/norg-specs/commit/67a8bca4d84b6a1e3e7457d39771d5247d06a6f5))
* allow 2-character delimiting modifiers ([2f607c4](https://github.com/nvim-neorg/norg-specs/commit/2f607c4b6063b09916e6552a833d01e3fb6118ff))
* attached modifier extensions (attributes) ([3658a2e](https://github.com/nvim-neorg/norg-specs/commit/3658a2e5d28aad74e2782a1260f3471d7923222b))
* be more precise in the rules for linkables ([b19f5c5](https://github.com/nvim-neorg/norg-specs/commit/b19f5c5e37c2d315ce167227519abeaafa7731a2))
* begin explaining basic semantics of standard ranged tags ([edfbde8](https://github.com/nvim-neorg/norg-specs/commit/edfbde85b6dcdabc5878188780790c7c3ea1b93b))
* change wiki link from `?` =&gt; `!` ([80f0245](https://github.com/nvim-neorg/norg-specs/commit/80f0245558a13ffb552b9c51e5a24cf7f5315705))
* expand macro tag section ([2465505](https://github.com/nvim-neorg/norg-specs/commit/24655052d12cba9802ad140679fe3332015bb3ce))
* finish ranged tag section ([a2c1b54](https://github.com/nvim-neorg/norg-specs/commit/a2c1b54bcbb8bcf381b943365d0a0cd469747894))
* infirm tag section ([bc6bb93](https://github.com/nvim-neorg/norg-specs/commit/bc6bb93a3b2ce77d7df48cb8c2ff8ad1dd001c5b))
* **proofread:** finalize proofread ([16cf680](https://github.com/nvim-neorg/norg-specs/commit/16cf680a7e5d34b2c40cdb8e72d35b5fa4ba685b))
* **proofreading:** finish proofreading ([b31316a](https://github.com/nvim-neorg/norg-specs/commit/b31316adbc14ec48cd45d47544e6b67050fbf822))
* **proofreading:** rewrite parts of the detached modifier extension section ([708b90b](https://github.com/nvim-neorg/norg-specs/commit/708b90b1b96e65506b01dd5eb2f2f2370278ff7f))
* range-able macros and variable definitions ([90059f2](https://github.com/nvim-neorg/norg-specs/commit/90059f2207439b08a04d38e9ae7bff2734459ff0))
* show disambiguation of link content with trailing modifier ([7252adc](https://github.com/nvim-neorg/norg-specs/commit/7252adcd8b2970684ca23423cb856f26aba3fde0))
* **spec:** add graphemes because everyone loves graphemes ([f489385](https://github.com/nvim-neorg/norg-specs/commit/f489385bd9da59c1a09739bd0ff6abebafddab88))
* **specification:** describe carryover tags in slides ([ae57c5d](https://github.com/nvim-neorg/norg-specs/commit/ae57c5dc45a9dd4282b0e00df1dec44054ac1751))
* **specification:** rename `comment` =&gt; `null modifier`, create null modifier section ([b0a8c21](https://github.com/nvim-neorg/norg-specs/commit/b0a8c21dd1caffb9d58a3568e39ed701283aa095))
* support wiki targets (?-char) ([31bfd4e](https://github.com/nvim-neorg/norg-specs/commit/31bfd4e0816ce73e9b15a60d6227023d131d982e))


### Bug Fixes

* attrib was misspelled in the Attributes example ([0f055cc](https://github.com/nvim-neorg/norg-specs/commit/0f055cc1e6637d7c29450756ca8ca9b33d0d8023))
* be more specific about path modifiers for file locations in links ([b4be6c4](https://github.com/nvim-neorg/norg-specs/commit/b4be6c4a7012a9f2beb7762f61ac8856d1a3a282))
* change trailing modifer vs. detached modifer precedence ([0a44264](https://github.com/nvim-neorg/norg-specs/commit/0a442643487bdefbb2239235560615dfd0556e30))
* clarify definition of a paragraph break ([#9](https://github.com/nvim-neorg/norg-specs/issues/9)) ([6f24e7d](https://github.com/nvim-neorg/norg-specs/commit/6f24e7d966b10d404682104eea5129ca29714097))
* disallow paragraph_break inside ranged attached mods ([dddddb8](https://github.com/nvim-neorg/norg-specs/commit/dddddb87d5a63cf7a6944fd401a553cdcd37f653))
* disallow whitespace on inner linkable boundaries ([0f4197f](https://github.com/nvim-neorg/norg-specs/commit/0f4197fac2b64e133d595ed02fc7d42e479603b9))
* **grammar:** non-defining relative clause should be a defining clause ([ab1cd26](https://github.com/nvim-neorg/norg-specs/commit/ab1cd26b03e97e44a8bb48f298eed69d57d883ae))
* ls-tex pass for typos ([#5](https://github.com/nvim-neorg/norg-specs/issues/5)) ([3ce2618](https://github.com/nvim-neorg/norg-specs/commit/3ce2618c1469a8f09a6f0b5dec49d796b022c9ab))
* missing wiki links in layer 4, broken link in layer 5 ([d9a0184](https://github.com/nvim-neorg/norg-specs/commit/d9a018431055289d0520eb40c2f4350c68c3cb11))
* modeline ([e2044ed](https://github.com/nvim-neorg/norg-specs/commit/e2044ed8a6dd3e707d64dc4d84f78d18b3c7016e))
* proofreading ([40e7504](https://github.com/nvim-neorg/norg-specs/commit/40e750413aaaf6a13c21e47db5490d54a2cb98fc))
* **proofreading:** clean up slide section yet again ([06b77c6](https://github.com/nvim-neorg/norg-specs/commit/06b77c63d972d9b766ea5eccb4bb4f5bca94f142))
* **proofreading:** improve detached modifier extensions and rewrite some slide and indent segment stuff ([0799977](https://github.com/nvim-neorg/norg-specs/commit/079997755626e2acf39e59009526a0ba12170635))
* **proofreading:** minor issues here and there ([b9efbf1](https://github.com/nvim-neorg/norg-specs/commit/b9efbf166a3b1331d05b0b8b4d78bc6f4c61f938))
* **proofreading:** work on tags and attached modifiers ([eff84ac](https://github.com/nvim-neorg/norg-specs/commit/eff84acac57ef6a7942ef884532cf06d36c9c2c8))
* revert wiki link to `?`, change extendable link to `=` ([8ab5a11](https://github.com/nvim-neorg/norg-specs/commit/8ab5a11dbb7601dd777fd1bbfa4f1d38c97e371a))
* some consistency things and a few extra notes ([1bad27b](https://github.com/nvim-neorg/norg-specs/commit/1bad27b4d88399da46ce17e57a9cb775f63742c9))
* **spec:** incorrect usage of footnote ([22f6d9b](https://github.com/nvim-neorg/norg-specs/commit/22f6d9b880f14c6390d59696f30b3d8480d13e95))
* **spec:** remove extraneous line that adds no extra information ([9283c7f](https://github.com/nvim-neorg/norg-specs/commit/9283c7f22a54db390aa923219bfcdaa8931994e9))
* state that nestable detached modifiers cannot be linked to ([3a597eb](https://github.com/nvim-neorg/norg-specs/commit/3a597ebf8707f9758f8351cb33f32dbaedcd28f4))
