import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const ShopeeAffiliateApp());
}

class ShopeeAffiliateApp extends StatelessWidget {
  const ShopeeAffiliateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Divulgador Shopee',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
        ),
        useMaterial3: true,
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
  final TextEditingController linkController =
      TextEditingController();

  String produto = '';
  String preco = '';
  String imagem = '';
  String linkFinal = '';

  bool carregando = false;

  Future<void> buscarProduto() async {
    final link = linkController.text.trim();

    if (link.isEmpty) {
      mostrarMensagem('Cole primeiro o link da Shopee.');
      return;
    }

    Uri? uri = Uri.tryParse(link);

    if (uri == null ||
        !uri.hasScheme ||
        (!uri.host.contains('shopee') &&
            !uri.host.contains('shp.ee'))) {
      mostrarMensagem('Digite um link válido da Shopee.');
      return;
    }

    setState(() {
      carregando = true;
      produto = '';
      preco = '';
      imagem = '';
      linkFinal = link;
    });

    try {
      final resultado = await obterDados(link);

      if (!mounted) return;

      setState(() {
        produto = resultado['produto'] ?? '';
        preco = resultado['preco'] ?? '';
        imagem = resultado['imagem'] ?? '';
        linkFinal = resultado['link'] ?? link;
        carregando = false;
      });

      if (produto.isEmpty) {
        mostrarMensagem(
          'Não foi possível encontrar os dados automaticamente. '
          'A Shopee pode bloquear a leitura desta página.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        carregando = false;
      });

      mostrarMensagem(
        'Não foi possível consultar o produto. '
        'Tente novamente.',
      );
    }
  }

  Future<Map<String, String>> obterDados(String link) async {
    final client = HttpClient();

    try {
      client.userAgent =
          'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
          '(KHTML, like Gecko) Chrome/120 Mobile Safari/537.36';

      final request = await client.getUrl(Uri.parse(link));

      request.headers.set(
        HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml',
      );

      request.headers.set(
        HttpHeaders.acceptLanguageHeader,
        'pt-BR,pt;q=0.9,en;q=0.8',
      );

      final response = await request.close();

      final bytes = await response.fold<List<int>>(
        <int>[],
        (previous, element) => previous..addAll(element),
      );

      final html = utf8.decode(bytes, allowMalformed: true);

      final titulo = extrairMeta(
        html,
        'og:title',
      );

      final imagemProduto = extrairMeta(
        html,
        'og:image',
      );

      String precoProduto = extrairMeta(
        html,
        'product:price:amount',
      );

      if (precoProduto.isEmpty) {
        precoProduto = extrairPreco(html);
      }

      String tituloFinal = titulo;

      if (tituloFinal.isEmpty) {
        tituloFinal = extrairTitle(html);
      }

      tituloFinal = limparTexto(tituloFinal);

      if (precoProduto.isNotEmpty) {
        precoProduto = formatarPreco(precoProduto);
      }

      return {
        'produto': tituloFinal,
        'preco': precoProduto,
        'imagem': imagemProduto,
        'link': link,
      };
    } finally {
      client.close(force: true);
    }
  }

  String extrairMeta(String html, String propriedade) {
    final padroes = [
      RegExp(
        '<meta[^>]+property=["\']$propriedade["\'][^>]+content=["\']([^"\']+)["\']',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']$propriedade["\']',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+name=["\']$propriedade["\'][^>]+content=["\']([^"\']+)["\']',
        caseSensitive: false,
      ),
    ];

    for (final padrao in padroes) {
      final match = padrao.firstMatch(html);

      if (match != null && match.groupCount >= 1) {
        return limparHtml(match.group(1) ?? '');
      }
    }

    return '';
  }

  String extrairTitle(String html) {
    final match = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);

    if (match != null) {
      return limparHtml(match.group(1) ?? '');
    }

    return '';
  }

  String extrairPreco(String html) {
    final padroes = [
      RegExp(
        r'"price"\s*:\s*"?(?:R\$)?\s*([0-9]+[.,][0-9]{2})',
        caseSensitive: false,
      ),
      RegExp(
        r'"price"\s*:\s*([0-9]+(?:\.[0-9]+)?)',
        caseSensitive: false,
      ),
      RegExp(
        r'R\$\s*([0-9]+[.,][0-9]{2})',
        caseSensitive: false,
      ),
    ];

    for (final padrao in padroes) {
      final match = padrao.firstMatch(html);

      if (match != null) {
        return match.group(1) ?? '';
      }
    }

    return '';
  }

  String limparHtml(String texto) {
    return texto
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  String limparTexto(String texto) {
    texto = limparHtml(texto);

    texto = texto.replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return texto.trim();
  }

  String formatarPreco(String valor) {
    valor = valor.trim();

    if (valor.startsWith('R\$')) {
      return valor;
    }

    return 'R\$ $valor';
  }

  String gerarTextoDivulgacao() {
    final nome = produto.isEmpty
        ? 'Produto Shopee'
        : produto;

    final valor = preco.isEmpty
        ? ''
        : '\n💰 Preço: $preco';

    return '''
🛍️ $nome
$valor

🔗 Comprar:
$linkFinal

🔥 Aproveite a oferta!
''';
  }

  Future<void> copiarDivulgacao() async {
    if (linkFinal.isEmpty) {
      mostrarMensagem('Busque primeiro um produto.');
      return;
    }

    await Clipboard.setData(
      ClipboardData(
        text: gerarTextoDivulgacao(),
      ),
    );

    mostrarMensagem(
      'Divulgação copiada!',
    );
  }

  Future<void> abrirWhatsApp() async {
    if (linkFinal.isEmpty) {
      mostrarMensagem('Busque primeiro um produto.');
      return;
    }

    final texto = Uri.encodeComponent(
      gerarTextoDivulgacao(),
    );

    final uri = Uri.parse(
      'https://wa.me/?text=$texto',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } else {
      mostrarMensagem(
        'Não foi possível abrir o WhatsApp.',
      );
    }
  }

  Future<void> abrirProduto() async {
    if (linkFinal.isEmpty) {
      mostrarMensagem('Nenhum link disponível.');
      return;
    }

    final uri = Uri.tryParse(linkFinal);

    if (uri == null) {
      mostrarMensagem('Link inválido.');
      return;
    }

    await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  void mostrarMensagem(String mensagem) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Divulgador Shopee',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),

            const Icon(
              Icons.shopping_bag,
              size: 70,
              color: Colors.deepOrange,
            ),

            const SizedBox(height: 12),

            const Text(
              'Divulgador de Produtos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Cole o link de um produto da Shopee '
              'para buscar as informações.',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            TextField(
              controller: linkController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Link da Shopee',
                hintText: 'https://shopee.com.br/...',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 14),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed:
                    carregando ? null : buscarProduto,
                icon: carregando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  carregando
                      ? 'Buscando...'
                      : 'Buscar produto',
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (produto.isNotEmpty ||
                imagem.isNotEmpty ||
                preco.isNotEmpty)
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      if (imagem.isNotEmpty)
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(12),
                          child: Image.network(
                            imagem,
                            height: 230,
                            fit: BoxFit.contain,
                            errorBuilder:
                                (context, error, stack) {
                              return const SizedBox(
                                height: 150,
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 70,
                                ),
                              );
                            },
                          ),
                        ),

                      const SizedBox(height: 15),

                      const Text(
                        'PRODUTO',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        produto.isEmpty
                            ? 'Nome não encontrado'
                            : produto,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      if (preco.isNotEmpty) ...[
                        const SizedBox(height: 14),

                        const Text(
                          'PREÇO',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.deepOrange,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          preco,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      OutlinedButton.icon(
                        onPressed: copiarDivulgacao,
                        icon: const Icon(Icons.copy),
                        label: const Text(
                          'Copiar divulgação',
                        ),
                      ),

                      const SizedBox(height: 8),

                      ElevatedButton.icon(
                        onPressed: abrirWhatsApp,
                        icon: const Icon(
                          Icons.share,
                        ),
                        label: const Text(
                          'Compartilhar no WhatsApp',
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextButton.icon(
                        onPressed: abrirProduto,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text(
                          'Abrir produto',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    linkController.dispose();
    super.dispose();
  }
}
