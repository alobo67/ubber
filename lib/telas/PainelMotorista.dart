import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:ubber/model/Requisicao.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ubber/util/StatusRequisicao.dart';

class PainelMotorista extends StatefulWidget {
  const PainelMotorista({Key? key}) : super(key: key);

  @override
  _PainelMotoristaState createState() => _PainelMotoristaState();
}

class _PainelMotoristaState extends State<PainelMotorista> {

  List<String> itensMenu = [
    "Configurações", "Deslogar"
  ];
  final _controller = StreamController<QuerySnapshot>.broadcast();
  FirebaseFirestore db = FirebaseFirestore.instance;

  _deslogarUsuario() async {

    FirebaseAuth auth = FirebaseAuth.instance;
    await auth.signOut();
    Navigator.pushReplacementNamed(context, "/");

  }

  _escolhaMenuItem( String escolha ){
    switch( escolha ){
      case "Deslogar" :
        _deslogarUsuario();
        break;
      case "Configurações" :
        _deslogarUsuario();
        break;
    }

  }

  Stream<QuerySnapshot>? _adicionarListenerRequisicoes(){
    
    final stream = db.collection("requisicoes")
        .where("status", isEqualTo: StatusRequisicao.AGUARDANDO)
        .snapshots();
    stream.listen((dados) {
      _controller.add( dados );
    });

  }

  @override
  void initState() {
    super.initState();
    _adicionarListenerRequisicoes();
  }

  @override
  Widget build(BuildContext context) {

    var mensagemCarregando = Center(
      child: Column(
        children: [
          Text("Carregando requisições"),
          CircularProgressIndicator()
        ],
      ),
    );

    var mensagemNaoTemDados = Center(
      child: Text(
        "Você não tem nenhume requisição :(",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text("Painel motorista"),
        actions: [
          PopupMenuButton<String>(
            onSelected: _escolhaMenuItem,
            itemBuilder: (context){

              return itensMenu.map((String item){

                return PopupMenuItem<String>(
                  value: item,
                  child: Text(item),
                );

              }).toList();

            },
          )
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
          stream: _controller.stream,
          builder: (context, snapshot) {
            switch ( snapshot.connectionState ){
              case ConnectionState.done:
              case ConnectionState.waiting:
                return mensagemCarregando;
                break;
              case ConnectionState.active:
              case ConnectionState.done:
                if( snapshot.hasError ){
                  return Text("Erro ao carregar os dados!");
                }else{

                  QuerySnapshot querySnapshot = snapshot.data!;
                  if( querySnapshot.docs.length == 0){
                    return mensagemNaoTemDados;
                  }else{

                    return ListView.separated(
                        itemCount: querySnapshot.docs.length,
                        separatorBuilder: (context, indice) => Divider(
                          height: 2,
                          color: Colors.grey,
                        ),
                        itemBuilder: (context, indice){

                          List<DocumentSnapshot> requisicoes = querySnapshot.docs.toList();
                          DocumentSnapshot item = requisicoes[ indice ];

                          String idRequisicao = item["id"];
                          String nomePassageiro = item["passageiro"]["nome"];
                          String rua = item["destino"]["rua"];
                          String numero = item["destino"]["numero"];

                          return ListTile(
                            title: Text( nomePassageiro ),
                            subtitle: Text("destino: $rua, $numero"),
                            onTap: (){
                              Navigator.pushNamed(
                                  context,
                                  "/corrida",
                                arguments: idRequisicao
                              );

                            },
                          );

                        }
                    );

                  }
                }
                break;
            }
            return Text("...");
          }
      ),
    );
  }
}