import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OrderHistoryPage(),
    );
  }
}

class OrderModel {
  final String id;
  final String item;
  final String price;
  final String status;
  final IconData icon;

  OrderModel({
    required this.id,
    required this.item,
    required this.price,
    required this.status,
    required this.icon,
  });
}

class OrderHistoryPage extends StatelessWidget {
  const OrderHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<OrderModel> orders = [
      OrderModel(
        id: "order_1",
        item: "Pizza Margherita",
        price: "₹450",
        status: "On the way",
        icon: Icons.local_pizza,
      ),
      OrderModel(
        id: "order_2",
        item: "Veg Burger",
        price: "₹299",
        status: "Delivered",
        icon: Icons.fastfood,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Orders"),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          final order = orders[index];
          final bool active = order.status == "On the way";

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: Icon(order.icon),
              title: Text(order.item),
              subtitle: Text(order.status),
              trailing: Text(order.price),
              onTap: () {
                if (active) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          TrackingPage(orderId: order.id),
                    ),
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}


class TrackingPage extends StatefulWidget {
  final String orderId;
  const TrackingPage({super.key, required this.orderId});

  @override
  State<TrackingPage> createState() => _TrackingPageState();
}

class _TrackingPageState extends State<TrackingPage> {
  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final List<LatLng> _routePoints = [];
  static const LatLng _center = LatLng(28.6139, 77.2090);
  void _updateCamera(LatLng pos) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: pos, zoom: 17, tilt: 45),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .doc(widget.orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Tracking data not available"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final LatLng currentPos = LatLng(
            (data['lat'] as num).toDouble(),
            (data['lng'] as num).toDouble(),
          );
          if (_routePoints.isEmpty || _routePoints.last != currentPos) {
            _routePoints.add(currentPos);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) => _updateCamera(currentPos));

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(target: currentPos, zoom: 15),
                onMapCreated: (controller) => _mapController = controller,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                compassEnabled: true,
                markers: {
                  Marker(
                    markerId: const MarkerId("delivery_boy"),
                    position: currentPos,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    infoWindow: const InfoWindow(title: "Delivery Partner is here"),
                  ),
                },
                polylines: {
                  Polyline(
                    polylineId: const PolylineId("path"),
                    points: _routePoints,
                    color: Colors.redAccent,
                    width: 6,
                    jointType: JointType.round,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                  ),
                },
              ),
              Positioned(
                bottom: 30,
                left: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.delivery_dining, color: Colors.red, size: 30),
                          ),
                          const SizedBox(width: 15),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("On the way",
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.red)),
                                Text("Your delivery partner is moving"),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () {},
                            icon: const CircleAvatar(
                              backgroundColor: Colors.green,
                              child: Icon(Icons.phone, color: Colors.white, size: 20),
                            ),
                          )
                        ],
                      ),
                      const Divider(height: 30),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Estimated Arrival", style: TextStyle(color: Colors.grey)),
                          Text("10-12 Mins", style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
