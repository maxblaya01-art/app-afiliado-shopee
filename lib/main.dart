import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const DivulgadorShopeeApp());
}

class DivulgadorShopeeApp extends StatelessWidget {
  const DivulgadorShopeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Divulgador Shopee',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8F6),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController linkController = TextEditingController();

  String produto = '';
  String preco = '';
  String imagem = '';
  String linkFinal = '';
  String erro = '';

  bool carregando = false;

  @override
  void dispose() {
    linkController.dispose();
    super.dispose();
  }

  // ============================================================
  // NORMALIZA O LINK DA SHOPEE
  // ============================================================

  String normalizarLink(String texto) {
    String link = texto.trim();

    // Corrige casos em que o usuário cola "s://..."
    if (link.startsWith('s://')) {
      link = 'https://' + link.substring(4);
    }

    // Corrige "//s.shopee.com.br/..."
    if (link.startsWith('//')) {
      link = 'https:$link';
    }

    // Adiciona HTTPS se necessário
    if (!link.startsWith('http://') &&
        !link.startsWith('https://')) {
      link = 'https://$link';
    }

    return link;
  }

  bool ehShopee(String link) {
    final texto = link.toLowerCase();

    return texto.contains('shopee.com.br') ||
        texto.contains('shopee.com') ||
        texto.contains('s.shopee');
  }

  // ============================================================
  // LIMPA TEXTO HTML
  // ============================================================

  String limparTexto(String texto) {
    String resultado = texto;

    resultado = resultado.replaceAll(
      RegExp(r'<[^>]*>'),
      ' ',
    );

    resultado = resultado.replaceAll('&amp;', '&');
    resultado = resultado.replaceAll('&quot;', '"');
    resultado = resultado.replaceAll('&#39;', "'");
    resultado = resultado.replaceAll('&apos;', "'");
    resultado = resultado.replaceAll('&lt;', '<');
    resultado = resultado.replaceAll('&gt;', '>');
    resultado = resultado.replaceAll('&nbsp;', ' ');

    resultado = resultado.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return resultado.trim();
  }

  // ============================================================
  // EXTRAI META TAG
  // ============================================================

  String extrairMeta(
    String html,
    String propriedade,
  ) {
    final padrao1 = RegExp(
      '<meta[^>]+property=["\']$propriedade["\'][^>]+content=["\']([^"\']+)["\']',
      caseSensitive: false,
    );

    final padrao2 = RegExp(
      '<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']$propriedade["\']',
      caseSensitive: false,
    );

    Match? match = padrao1.firstMatch(html);

    match ??= padrao2.firstMatch(html);

    if (match != null) {
      return limparTexto(match.group(1) ?? '');
    }

    return '';
  }

  // ============================================================
  // EXTRAI META NAME
  // ============================================================

  String extrairMetaName(
    String html,
    String nome,
  ) {
    final padrao1 = RegExp(
      '<meta[^>]+name=["\']$nome["\'][^>]+content=["\']([^"\']+)["\']',
      caseSensitive: false,
    );

    final padrao2 = RegExp(
      '<meta[^>]+content=["\']([^"\']+)["\'][^>]+name=["\']$nome["\']',
      caseSensitive: false,
    );

    Match? match = padrao1.firstMatch(html);

    match ??= padrao2.firstMatch(html);

    if (match != null) {
      return limparTexto(match.group(1) ?? '');
    }

    return '';
  }

  // ============================================================
  // EXTRAI TÍTULO
  // ============================================================

  String extrairTitulo(String html) {
    String titulo = extrairMeta(html, 'og:title');

    if (titulo.isNotEmpty) {
      return titulo;
    }

    titulo = extrairMetaName(html, 'twitter:title');

    if (titulo.isNotEmpty) {
      return titulo;
    }

    final match = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);

    if (match != null) {
      return limparTexto(match.group(1) ?? '');
    }

    return '';
  }

  // ============================================================
  // EXTRAI IMAGEM
  // ============================================================

  String extrairImagem(String html) {
    String imagem = extrairMeta(html, 'og:image');

    if (imagem.isNotEmpty) {
      return imagem;
    }

    imagem = extrairMetaName(html, 'twitter:image');

    if (imagem.isNotEmpty) {
      return imagem;
    }

    // Tenta encontrar uma imagem em Markdown
    final markdown = RegExp(
      r'!\[[^\]]*\]\((https?://[^)\s]+)',
      caseSensitive: false,
    ).firstMatch(html);

    if (markdown != null) {
      return markdown.group(1) ?? '';
    }

    // Tenta encontrar qualquer imagem
    final imagemGenerica = RegExp(
      r'https?://[^\s"\']+\.(?:jpg|jpeg|png|webp)',
      caseSensitive: false,
    ).firstMatch(html);

    if (imagemGenerica != null) {
      return imagemGenerica.group(0) ?? '';
    }

    return '';
  }

  // ============================================================
  // EXTRAI PREÇO
  // ============================================================

  String extrairPreco(String texto) {
    final padroes = <RegExp>[
      RegExp(
        r'R\$\s*\d{1,3}(?:\.\d{3})*(?:,\d{2})?',
        caseSensitive: false,
      ),
      RegExp(
        r'BRL\s*\d{1,3}(?:\.\d{3})*(?:,\d{2})?',
        caseSensitive: false,
      ),
    ];

    for (final padrao in padroes) {
      final match = padrao.firstMatch(texto);

      if (match != null) {
        return match.group(0) ?? '';
      }
    }

    return '';
  }

  // ============================================================
  // BUSCA DIRETAMENTE NA SHOPEE
  // ============================================================

  Future<Map<String, String>?> buscarDireto(
    String link,
  ) async {
    try {
      final client = http.Client();

      try {
        final uri = Uri.parse(link);

        final resposta = await client
            .get(
              uri,
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
                'Accept':
                    'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
                'Accept-Language':
                    'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
                'Cache-Control': 'no-cache',
              },
            )
            .timeout(
              const Duration(seconds: 20),
            );

        final html = utf8.decode(
          resposta.bodyBytes,
          allowMalformed: true,
        );

        if (resposta.statusCode >= 200 &&
            resposta.statusCode < 400 &&
            html.isNotEmpty) {
          final titulo = extrairTitulo(html);
          final imagem = extrairImagem(html);
          final texto = limparTexto(html);
          final precoEncontrado = extrairPreco(texto);

          final urlFinal =
              resposta.request?.url.toString() ?? link;

          if (titulo.isNotEmpty ||
              imagem.isNotEmpty ||
              precoEncontrado.isNotEmpty) {
            return {
              'produto': titulo.isNotEmpty
                  ? titulo
                  : 'Produto Shopee',
              'preco': precoEncontrado.isNotEmpty
                  ? precoEncontrado
                  : 'Preço não encontrado',
              'imagem': imagem,
              'link': urlFinal,
            };
          }
        }
      } finally {
        client.close();
      }
    } catch (_) {
      // Continua para o método alternativo.
    }

    return null;
  }

  // ============================================================
  // MÉTODO ALTERNATIVO
  // ============================================================

  Future<Map<String, String>?> buscarAlternativo(
    String link,
  ) async {
    try {
      final url =
          'https://r.jina.ai/$link';

      final resposta = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36',
          'Accept': 'text/plain,text/html,*/*',
        },
      ).timeout(
        const Duration(seconds: 30),
      );

      if (resposta.statusCode >= 200 &&
          resposta.statusCode < 400) {
        final texto = utf8.decode(
          resposta.bodyBytes,
          allowMalformed: true,
        );

        if (texto.trim().isEmpty) {
          return null;
        }

        String titulo = '';

        // Título em Markdown
        final tituloMarkdown = RegExp(
          r'^#\s+(.+)$',
          multiLine: true,
        ).firstMatch(texto);

        if (tituloMarkdown != null) {
          titulo =
              limparTexto(tituloMarkdown.group(1) ?? '');
        }

        // Tenta procurar "Title:"
        if (titulo.isEmpty) {
          final titleMatch = RegExp(
            r'(?:Title|Título)\s*:\s*(.+)',
            caseSensitive: false,
          ).firstMatch(texto);

          if (titleMatch != null) {
            titulo =
                limparTexto(titleMatch.group(1) ?? '');
          }
        }

        final precoEncontrado = extrairPreco(texto);

        String imagem = '';

        final imagemMatch = RegExp(
          r'!\[[^\]]*\]\((https?://[^)\s]+)',
          caseSensitive: false,
        ).firstMatch(texto);

        if (imagemMatch != null) {
          imagem = imagemMatch.group(1) ?? '';
        }

        // Procura URL de imagem
        if (imagem.isEmpty) {
          final imagemGenerica = RegExp(
            r'https?://[^\s\]\)"]+\.(?:jpg|jpeg|png|webp)',
            caseSensitive: false,
          ).firstMatch(texto);

          if (imagemGenerica != null) {
            imagem =
                imagemGenerica.group(0) ?? '';
          }
        }

        if (titulo.isNotEmpty ||
            precoEncontrado.isNotEmpty ||
            imagem.isNotEmpty) {
          return {
            'produto': titulo.isNotEmpty
                ? titulo
                : 'Produto Shopee',
            'preco': precoEncontrado.isNotEmpty
                ? precoEncontrado
                : 'Preço não encontrado',
            'imagem': imagem,
            'link': link,
          };
        }
      }
    } catch (_) {
      // Falha no método alternativo.
    }

    return null;
  }

  // ============================================================
  // BUSCAR PRODUTO
  // ============================================================

  Future<void> buscarProduto() async {
    FocusScope.of(context).unfocus();

    final texto = linkController.text.trim();

    if (texto.isEmpty) {
      setState(() {
        erro = 'Cole o link do produto da Shopee.';
      });
      return;
    }

    final link = normalizarLink(texto);

    if (!ehShopee(link)) {
      setState(() {
        erro = 'Esse link não parece ser um link da Shopee.';
      });
      return;
    }

    setState(() {
      carregando = true;
      erro = '';
      produto = '';
      preco = '';
      imagem = '';
      linkFinal = '';
    });

    Map<String, String>? dados;

    // Primeiro tenta diretamente
    dados = await buscarDireto(link);

    // Se não conseguir, tenta método alternativo
    if (dados == null) {
      dados = await buscarAlternativo(link);
    }

    if (!mounted) {
      return;
    }

    if (dados != null) {
      setState(() {
        produto =
            dados!['produto'] ?? 'Produto Shopee';

        preco =
            dados['preco'] ?? 'Preço não encontrado';

        imagem =
            dados['imagem'] ?? '';

        linkFinal =
            dados['link'] ?? link;

        erro = '';
        carregando = false;
      });
    } else {
      setState(() {
        carregando = false;

        erro =
            'Não foi possível carregar os dados deste produto. '
            'A Shopee pode ter bloqueado o acesso automático ao link.';
      });
    }
  }

  // ============================================================
  // GERAR TEXTO DE DIVULGAÇÃO
  // ============================================================

  String gerarTextoDivulgacao() {
    final nome = produto.isNotEmpty
        ? produto
        : 'Produto Shopee';

    final valor = preco.isNotEmpty
        ? preco
        : 'Confira o preço';

    final link = linkFinal.isNotEmpty
        ? linkFinal
        : linkController.text.trim();

    return '''
🛍️ $nome

💰 Preço: $valor

🔥 Aproveite a oferta!

👉 Compre aqui:
$link
''';
  }

  Future<void> copiarDivulgacao() async {
    final texto = gerarTextoDivulgacao();

    await Clipboard.setData(
      ClipboardData(text: texto),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Divulgação copiada! Agora é só colar no WhatsApp.',
        ),
      ),
    );
  }

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Divulgador Shopee',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              // ==================================================
              // CAMPO DO LINK
              // ==================================================

              TextField(
                controller: linkController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText:
                      'Link do produto Shopee',
                  prefixIcon:
                      const Icon(Icons.link),
                  hintText:
                      'https://s.shopee.com.br/...',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),

              const SizedBox(height: 18),

              // ==================================================
              // BOTÃO BUSCAR
              // ==================================================

              SizedBox(
                height: 58,
                child: ElevatedButton.icon(
                  onPressed:
                      carregando
                          ? null
                          : buscarProduto,
                  icon: carregando
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.search,
                        ),
                  label: Text(
                    carregando
                        ? 'CARREGANDO...'
                        : 'BUSCAR PRODUTO',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        30,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // ==================================================
              // ERRO
              // ==================================================

              if (erro.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.orange
                        .withOpacity(0.10),
                    borderRadius:
                        BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.orange
                          .withOpacity(0.40),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        color: Colors.deepOrange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          erro,
                          style:
                              const TextStyle(
                            fontSize: 16,
                            color:
                                Colors.deepOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ==================================================
              // PRODUTO
              // ==================================================

              if (produto.isNotEmpty ||
                  imagem.isNotEmpty)
                const SizedBox(height: 20),

              if (produto.isNotEmpty ||
                  imagem.isNotEmpty)
                Card(
                  elevation: 3,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        // IMAGEM
                        if (imagem.isNotEmpty)
                          ClipRRect(
                            borderRadius:
                                BorderRadius
                                    .circular(15),
                            child:
                                Image.network(
                              imagem,
                              width:
                                  double.infinity,
                              height: 260,
                              fit: BoxFit.contain,
                              errorBuilder:
                                  (
                                context,
                                error,
                                stackTrace,
                              ) {
                                return Container(
                                  height: 260,
                                  color:
                                      Colors.grey[
                                          200],
                                  child:
                                      const Icon(
                                    Icons
                                        .image_not_supported,
                                    size: 60,
                                    color:
                                        Colors.grey,
                                  ),
                                );
                              },
                              loadingBuilder:
                                  (
                                context,
                                child,
                                progress,
                              ) {
                                if (progress ==
                                    null) {
                                  return child;
                                }

                                return SizedBox(
                                  height: 260,
                                  child:
                                      Center(
                                    child:
                                        CircularProgressIndicator(
                                      value: progress
                                          .expectedTotalBytes !=
                                          null
                                          ? progress
                                                  .cumulativeBytesLoaded /
                                              progress
                                                  .expectedTotalBytes!
                                          : null,
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          Container(
                            width:
                                double.infinity,
                            height: 260,
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.grey[200],
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                15,
                              ),
                            ),
                            child:
                                const Icon(
                              Icons.image,
                              size: 60,
                              color:
                                  Colors.grey,
                            ),
                          ),

                        const SizedBox(height: 20),

                        const Text(
                          'PRODUTO',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          produto.isNotEmpty
                              ? produto
                              : 'Produto Shopee',
                          style:
                              const TextStyle(
                            fontSize: 23,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 18),

                        const Text(
                          'PREÇO',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          preco.isNotEmpty
                              ? preco
                              : 'Preço não encontrado',
                          style:
                              const TextStyle(
                            fontSize: 24,
                            fontWeight:
                                FontWeight.bold,
                            color:
                                Colors.deepOrange,
                          ),
                        ),

                        const SizedBox(height: 20),

                        const Text(
                          'LINK DE DIVULGAÇÃO',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 6),

                        SelectableText(
                          linkFinal.isNotEmpty
                              ? linkFinal
                              : linkController
                                  .text,
                          style:
                              const TextStyle(
                            color: Colors.blue,
                            fontSize: 15,
                          ),
                        ),

                        const SizedBox(height: 20),

                        SizedBox(
                          width:
                              double.infinity,
                          height: 52,
                          child:
                              ElevatedButton
                                  .icon(
                            onPressed:
                                copiarDivulgacao,
                            icon:
                                const Icon(
                              Icons
                                  .content_copy,
                            ),
                            label: const Text(
                              'GERAR DIVULGAÇÃO',
                              style:
                                  TextStyle(
                                fontSize: 16,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                            style:
                                ElevatedButton
                                    .styleFrom(
                              shape:
                                  RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  25,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 30),

              const Center(
                child: Text(
                  'Cole o link da Shopee e toque em BUSCAR PRODUTO.',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
