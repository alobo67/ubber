import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:geocoding/geocoding.dart';

import 'package:ubber/model/Destino.dart';
import 'package:ubber/model/Requisicao.dart';
import 'package:ubber/model/Usuario.dart';
import 'package:ubber/util/StatusRequisicao.dart';
import 'package:ubber/util/UsuarioFirebase.dart';


class PainelPassageiro extends StatefulWidget {
  const PainelPassageiro({Key? key}) : super(key: key);

  @override
  _PainelPassageiroState createState() => _PainelPassageiroState();
}

class _PainelPassageiroState extends State<PainelPassageiro> {

  TextEditingController _controllerDestino = TextEditingController(text: "Rua das Primaveras, 270");

  List<String> itensMenu = [
    "Configurações", "Deslogar"
  ];
  Completer<GoogleMapController> _controller = Completer();
  CameraPosition _posicaoCamera = CameraPosition(
    target: LatLng(-23.557425201980767, -46.65672565205034)
  );
  Set<Marker> _marcadores = {};
  late String _idRequisicao;

  //Controles para exibição na tela
  bool _exibirCaixaEnderecoDestino = true;
  String _textoBotao = "Chamar uber";
  Color _corBotao = Color(0xff1ebbd8);
  Function()? _funcaoBotao;

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

  _onMapCreated( GoogleMapController controller ){
    _controller.complete( controller );
  }

  _adcionarListenerLocalizacao(){

    var geolocator = Geolocator();
    var locationOptions = LocationOptions(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10
    );
    Geolocator.getPositionStream().listen((Position position) {

      setState(() {

        _exibirMarcadorPassageiro( position );

        _posicaoCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 19
        );
        _movimentarCamera(_posicaoCamera );
      });

    });

  }

  _recuperaUltimaLocalizacao() async {

    Position? position = await Geolocator
        .getLastKnownPosition();

    setState(() {
      if( position != null ){

        _exibirMarcadorPassageiro( position );

        _posicaoCamera = CameraPosition(
            target: LatLng(position.latitude, position.longitude),
          zoom: 19
        );

        _movimentarCamera( _posicaoCamera );
      }
    });

  }

  _movimentarCamera( CameraPosition cameraPosition ) async {

    GoogleMapController googleMapController = await _controller.future;
    googleMapController.animateCamera(
        CameraUpdate.newCameraPosition(
            cameraPosition
        )
    );

  }

  _exibirMarcadorPassageiro(Position local) async {

    double pixeRatio =  MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixeRatio),
        "imagens/passageiro.png"
    ).then((BitmapDescriptor icone) {

      Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-passageiro"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(
              title: "Meu local"
          ),
          icon: icone
      );

      setState(() {
        _marcadores.add( marcadorPassageiro );
      });

    });


  }

  _chamarUber() async {

    String enderecoDestino = _controllerDestino.text;


    if( enderecoDestino.isNotEmpty ){

      var locations  = await locationFromAddress(enderecoDestino, localeIdentifier: "pt_BR");
      //List<Placemark> listaEnderecos = await placemarkFromCoordinates(locations[0].longitude,locations[0].latitude);
      var listaEnderecos = await placemarkFromCoordinates(locations[0].latitude,locations[0].longitude, localeIdentifier: "pt_BR");

      if( listaEnderecos != null && listaEnderecos.length > 0){

        final Placemark endereco = listaEnderecos.first;
        Destino destino = Destino();
        destino.cidade = endereco.subAdministrativeArea!;
        destino.cep = endereco.postalCode!;
        destino.bairro = endereco.subLocality!;
        destino.rua = endereco.thoroughfare!;
        destino.numero = endereco.subThoroughfare!;

        destino.latitude = locations[0].latitude;
        destino.longitude = locations[0].longitude;

        String  enderecoConfirmacao;
        enderecoConfirmacao = "\n Cidade: " + destino.cidade;
        enderecoConfirmacao += "\n Rua: " + destino.rua + "," + destino.numero ;
        enderecoConfirmacao += "\n Bairro: " + destino.bairro ;
        enderecoConfirmacao += "\n Cep: " + destino.cep ;

        showDialog(
            context: context,
            builder: (context){
              return AlertDialog(
                title: Text("Confirmação do endereço"),
                content: Text(enderecoConfirmacao),
                contentPadding: EdgeInsets.all(16),
                actions: [
                  FlatButton(
                    child: Text("Cancelar", style: TextStyle(color: Colors.red),),
                    onPressed: () => Navigator.pop(context),
                  ),
                  FlatButton(
                    child: Text("Confirmar", style: TextStyle(color: Colors.green),),
                    onPressed: (){

                      //salvar requisicao
                      _salvarRequisicao( destino );

                      Navigator.pop(context);

                    },
                  )
                ],
              );
          }
        );

      }


    }

  }

  _salvarRequisicao( Destino destino ) async {
    /*
    + requisicao
      + ID_REQUISICAO
      + destino
      + passageiro
      + motorista
      + status

    * */
    Usuario passageiro = await UsuarioFirebase.getDadosUsuarioLogado();

    Requisicao requisicao = Requisicao();
    requisicao.destino = destino;
    requisicao.passageiro =  passageiro;
    requisicao.status = StatusRequisicao.AGUARDANDO;

    FirebaseFirestore db = FirebaseFirestore.instance;

    //salvar requisição
    db.collection("requisicoes")
        .doc( requisicao.id )
    .set( requisicao.toMap() );

    //Salvar requisição ativa
    Map<String, dynamic> dadosRequisicaoAtiva = {};
    dadosRequisicaoAtiva["id_requisicao"] = requisicao.id;
    dadosRequisicaoAtiva["id_usuario"] = passageiro.idUsuario;
    dadosRequisicaoAtiva["status"] = StatusRequisicao.AGUARDANDO;

    db.collection("requisicao_ativa")
    .doc( passageiro.idUsuario )
    .set( dadosRequisicaoAtiva );

  }

  _alterarBotaoPrincipal(String texto, Color cor, Function()? funcao){

    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });

  }

  _statusUberNaoChamado(){

    _exibirCaixaEnderecoDestino = true;

    _alterarBotaoPrincipal(
        "Chamar uber",
        Color(0xff1ebbd8),
        (){
          _chamarUber();
         }
     );

  }

  _statusAguardando(){

    _exibirCaixaEnderecoDestino = false;

    _alterarBotaoPrincipal(
        "Cancelar",
        Colors.red,
            (){
          _cancelarUber();
        }
    );

  }

  _cancelarUber() async {

    var usuarioLogado = await FirebaseAuth.instance.currentUser;

    FirebaseFirestore db = FirebaseFirestore.instance;
    db.collection("requisicoes")
    .doc( _idRequisicao ).update({
      "status" : StatusRequisicao.CANCELADA
    }).then((_) {

      db.collection("requisicao_ativa")
          .doc( usuarioLogado!.uid )
          .delete();
    });

  }

  _adicionarListenerRequisicaoAtiva() async {
    FirebaseAuth auth = FirebaseAuth.instance;

    var usuarioLogado = await FirebaseAuth.instance.currentUser;

    FirebaseFirestore db = FirebaseFirestore.instance;
    await db.collection("requisicao_ativa")
            .doc( usuarioLogado!.uid )
            .snapshots()
            .listen((snapshot) {
              print("dados recuperador: " + snapshot.data().toString());

              /*
                  Caso tenha uma requisicção ativa
                    -> altera interface de acordo com status
                  Caso não tenha
                    -> Exibe interface padrão para chamar uber
              */
              if( snapshot.data() != null){

                Map<String, dynamic>? dados = snapshot.data();
                String status = dados!["status"];
                _idRequisicao = dados!["id_requisicao"];

                switch( status ){
                  case StatusRequisicao.AGUARDANDO :
                    _statusAguardando();
                    break;
                  case StatusRequisicao.A_CAMINHO :

                    break;
                  case StatusRequisicao.VIAGEM :

                    break;
                  case StatusRequisicao.FINALIZADA :

                    break;

                }

              }else {

                _statusUberNaoChamado();

              }


    });

  }


  @override
  void initState() {
    super.initState();
    _recuperaUltimaLocalizacao();
    _adcionarListenerLocalizacao();

    //adcionar listener para requisicao ativa
    _adicionarListenerRequisicaoAtiva();

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel passageiro"),
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
      body: Container(
        child: Stack(
          children: [
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _posicaoCamera,
              onMapCreated: _onMapCreated,
              //myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: _marcadores,
            ),
            Visibility(
              visible: _exibirCaixaEnderecoDestino,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.white
                        ),
                        child: TextField(
                          readOnly: true,
                          decoration: InputDecoration(
                              icon: Container(
                                margin: EdgeInsets.only(left: 20, top: 5),
                                width: 10,
                                height: 10,
                                child: Icon(Icons.location_on, color: Colors.green,),
                              ),
                              hintText: "Meu local",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(left: 15, top: 16)
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 55,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.all(10),
                      child: Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.white
                        ),
                        child: TextField(
                          controller: _controllerDestino,
                          decoration: InputDecoration(
                              icon: Container(
                                margin: EdgeInsets.only(left: 20, top: 5),
                                width: 10,
                                height: 10,
                                child: Icon(Icons.local_taxi, color: Colors.black,),
                              ),
                              hintText: "Digite o destino",
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.only(left: 15, top: 16)
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
            Positioned(
              right: 0,
              left: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.all(10),
                child: RaisedButton(
                    child: Text(
                      _textoBotao,
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    color: _corBotao,
                    padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                    onPressed: _funcaoBotao
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}