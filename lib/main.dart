import 'dart:math';
import 'package:flutter/material.dart';

// Definición de los estados de la materia
enum EnvironmentState { idealAbstract, realAbstract, stableAbstract }

// Definición de los modos de experimentación
enum ExperimentMode { free, guided }

// Clase para las constantes de la simulación, ahora ajustables por el entorno
class EnvironmentConstants {
  final double attractionForceScale;
  final double repulsionForceScale;
  final double dampingFactor;
  final double bondThreshold;
  final double centralAttractionFactor;
  final double bondBreakThresholdFactor;

  const EnvironmentConstants({
    required this.attractionForceScale,
    required this.repulsionForceScale,
    required this.dampingFactor,
    required this.bondThreshold,
    required this.centralAttractionFactor,
    required this.bondBreakThresholdFactor,
  });

  // Estado idealAbstract
  static const EnvironmentConstants idealAbstract = EnvironmentConstants(
    attractionForceScale: 0.001,
    repulsionForceScale: 50.0,
    dampingFactor: 0.9,
    bondThreshold: 150.0,
    centralAttractionFactor: 0.00001,
    bondBreakThresholdFactor: 2.5,
  );

  // Estado realAbstract
  static const EnvironmentConstants realAbstract = EnvironmentConstants(
    attractionForceScale: 0.001,
    repulsionForceScale: 50.0,
    dampingFactor: 0.9,
    bondThreshold: 100.0,
    centralAttractionFactor: 0.00001,
    bondBreakThresholdFactor: 1.5,
  );

  // Nuevo estado para la fase de conformación de la molécula
  static const EnvironmentConstants stableAbstract = EnvironmentConstants(
    attractionForceScale: 0.005, // AUMENTADO: Enlaces más fuertes
    repulsionForceScale: 20.0, // REDUCIDO: Menos repulsión
    dampingFactor: 0.95, // AUMENTADO: Mayor estabilidad
    bondThreshold: 200.0, // AUMENTADO: Umbral de enlace más amplio
    centralAttractionFactor: 0.0001, // AUMENTADO: Se agrupan más rápido
    bondBreakThresholdFactor: 4.0, // AUMENTADO: Enlaces mucho más estables
  );
}

// Clase para encapsular las reglas químicas
class ChemRuleEngine {
  static String getBondType(Element e1, Element e2) {
    final deltaEN = (e1.electronegativity - e2.electronegativity).abs();

    if (e1.isMetal && e2.isMetal) {
      return 'Enlace Metálico';
    } else if (deltaEN > 1.7) {
      return 'Enlace Iónico';
    } else if (deltaEN > 0.4) {
      return 'Enlace Covalente Polar';
    } else {
      return 'Enlace Covalente No Polar';
    }
  }

  static Color getAtomColor(Element element) {
    if (element.isMetal) {
      return Colors.blue[800]!;
    } else if (['B', 'Si', 'Ge', 'As', 'Sb', 'Te', 'Po', 'At'].contains(element.symbol)) {
      return Colors.orange[700]!;
    } else {
      return Colors.red[800]!;
    }
  }

  static String getElementType(Element element) {
    if (element.isMetal) {
      return 'Metal';
    } else if (['B', 'Si', 'Ge', 'As', 'Sb', 'Te', 'Po', 'At'].contains(element.symbol)) {
      return 'Semimetal';
    } else {
      return 'No Metal';
    }
  }
}

// Modelo para un elemento de la tabla periódica
class Element {
  final int atomicNumber;
  final String symbol;
  final String name;
  final double electronegativity;
  final bool isMetal;
  final double atomicRadius;
  final double atomicWeight;
  final List<int> valences;

  Element({
    required this.atomicNumber,
    required this.symbol,
    required this.name,
    required this.electronegativity,
    required this.isMetal,
    required this.atomicRadius,
    required this.atomicWeight,
    required this.valences,
  });
}

// Modelo de átomo en la simulación
class Atom {
  final Element element;
  Offset position;
  Offset velocity;
  final double mass;
  final int id;
  int bondsFormed = 0;
  List<Atom> bondedTo = [];
  List<double> electronAngles = [];
  List<double> electronRadii = [];

  Atom({
    required this.element,
    required this.position,
    required this.id,
    this.velocity = Offset.zero,
    this.mass = 1.0,
  });
}

// Motor de física para la simulación
class PhysicsEngine {
  List<Atom> atoms = [];
  Map<String, List<Atom>> elementGroups = {};
  EnvironmentConstants constants;
  double centralAttractionMultiplier = 1.0;

  PhysicsEngine({required this.constants});

  void addAtom(Element element, Size simulationAreaSize) {
    final newId = atoms.length;
    Offset initialPosition;

    initialPosition = Offset(
      Random().nextDouble() * simulationAreaSize.width,
      Random().nextDouble() * simulationAreaSize.height,
    );

    final newAtom = Atom(
      element: element,
      position: initialPosition,
      id: newId,
      mass: element.atomicRadius / 100.0,
    );
    atoms.add(newAtom);
    elementGroups.putIfAbsent(element.symbol, () => []).add(newAtom);
  }

  void setEnvironment(EnvironmentConstants newConstants) {
    constants = newConstants;
  }

  void update(Size simulationAreaSize) {
    for (var atom in atoms) {
      Offset totalForce = Offset.zero;

      // Fuerza de atracción al centro
      final center = Offset(simulationAreaSize.width / 2, simulationAreaSize.height / 2);
      final dxCenter = center.dx - atom.position.dx;
      final dyCenter = center.dy - atom.position.dy;
      final distCenter = sqrt(dxCenter * dxCenter + dyCenter * dyCenter);
      totalForce += Offset(dxCenter, dyCenter) * (distCenter * constants.centralAttractionFactor * centralAttractionMultiplier);

      for (var other in atoms) {
        if (atom.id == other.id) continue;

        final dx = other.position.dx - atom.position.dx;
        final dy = other.position.dy - atom.position.dy;
        final distance = sqrt(dx * dx + dy * dy);

        if (distance == 0) continue;

        double repulsionForce = constants.repulsionForceScale / pow(distance, 2);
        final double deltaEN = (atom.element.electronegativity - other.element.electronegativity).abs();
        double attractionForce = 0.0;

        if (deltaEN > 1.7) {
          attractionForce = constants.attractionForceScale * 1.5;
        } else if (deltaEN > 0.4) {
          attractionForce = constants.attractionForceScale * 1.0;
        } else {
          attractionForce = constants.attractionForceScale * 0.5;
        }

        final expectedBondDistance = (atom.element.atomicRadius + other.element.atomicRadius) * 0.5;
        if (distance < expectedBondDistance) {
          repulsionForce *= 2.0;
          attractionForce = 0.0;
        }

        final double netForce = attractionForce - repulsionForce;
        totalForce += Offset(dx, dy) * netForce;
      }

      atom.velocity += totalForce / atom.mass;
      atom.velocity *= constants.dampingFactor;
      atom.position += atom.velocity;

      // Lógica de rebote en los bordes
      final double radius = atom.element.atomicRadius / 10;
      if (atom.position.dx < radius) {
        atom.position = Offset(radius, atom.position.dy);
        atom.velocity = Offset(-atom.velocity.dx, atom.velocity.dy);
      } else if (atom.position.dx > simulationAreaSize.width - radius) {
        atom.position = Offset(simulationAreaSize.width - radius, atom.position.dy);
        atom.velocity = Offset(-atom.velocity.dx, atom.velocity.dy);
      }
      if (atom.position.dy < radius) {
        atom.position = Offset(atom.position.dx, radius);
        atom.velocity = Offset(atom.velocity.dx, -atom.velocity.dy);
      } else if (atom.position.dy > simulationAreaSize.height - radius) {
        atom.position = Offset(atom.position.dx, simulationAreaSize.height - radius);
        atom.velocity = Offset(atom.velocity.dx, -atom.velocity.dy);
      }
    }

    // Lógica para romper enlaces si están demasiado estirados
    Set<List<Atom>> bondsToBreak = {};
    for (var atom in atoms) {
      List<Atom> currentBonds = List.from(atom.bondedTo);
      for (var other in currentBonds) {
        final dx = other.position.dx - atom.position.dx;
        final dy = other.position.dy - atom.position.dy;
        final distance = sqrt(dx * dx + dy * dy);
        final expectedBondDistance = (atom.element.atomicRadius + other.element.atomicRadius) * 0.5;
        final bondBreakThreshold = expectedBondDistance * constants.bondBreakThresholdFactor;

        final sortedPair = [atom.id, other.id]..sort();
        final bondKey = '${sortedPair[0]}-${sortedPair[1]}';

        if (distance > bondBreakThreshold) {
          bondsToBreak.add([atom, other]);
        }
      }
    }

    for (var bond in bondsToBreak) {
      final atom1 = bond[0];
      final atom2 = bond[1];
      if (atom1.bondedTo.contains(atom2)) {
        atom1.bondedTo.remove(atom2);
        atom1.bondsFormed--;
      }
      if (atom2.bondedTo.contains(atom1)) {
        atom2.bondedTo.remove(atom1);
        atom2.bondsFormed--;
      }
    }

    // Lógica para formar enlaces
    for (var atom in atoms) {
      final maxValence = atom.element.valences.isNotEmpty ? atom.element.valences.reduce(max) : 0;
      if (atom.bondsFormed < maxValence) {
        for (var other in atoms) {
          if (atom.id == other.id || atom.bondedTo.contains(other)) continue;
          final dx = other.position.dx - atom.position.dx;
          final dy = other.position.dy - atom.position.dy;
          final distance = sqrt(dx * dx + dy * dy);

          final expectedBondDistance = (atom.element.atomicRadius + other.element.atomicRadius) * 0.5;
          if (distance < expectedBondDistance + constants.bondThreshold) {
            atom.bondedTo.add(other);
            atom.bondsFormed++;
            other.bondedTo.add(atom);
            other.bondsFormed++;
            atom.velocity = Offset.zero;
            other.velocity = Offset.zero;
            final angle = atan2(dy, dx);
            final newX = atom.position.dx + cos(angle) * (distance - expectedBondDistance);
            final newY = atom.position.dy + sin(angle) * (distance - expectedBondDistance);
            other.position = Offset(newX, newY);
          }
        }
      }
    }
  }

  void clear() {
    atoms.clear();
    elementGroups.clear();
  }
}

// Datos de la tabla periódica completa (simplificada)
final List<Element> periodicTable = [
  Element(atomicNumber: 1, symbol: 'H', name: 'Hidrógeno', electronegativity: 2.20, isMetal: false, atomicRadius: 53.0, atomicWeight: 1.008, valences: [1]),
  Element(atomicNumber: 2, symbol: 'He', name: 'Helio', electronegativity: 0.0, isMetal: false, atomicRadius: 31.0, atomicWeight: 4.0026, valences: [0]),
  Element(atomicNumber: 3, symbol: 'Li', name: 'Litio', electronegativity: 0.98, isMetal: true, atomicRadius: 167.0, atomicWeight: 6.94, valences: [1]),
  Element(atomicNumber: 4, symbol: 'Be', name: 'Berilio', electronegativity: 1.57, isMetal: true, atomicRadius: 112.0, atomicWeight: 9.0122, valences: [2]),
  Element(atomicNumber: 5, symbol: 'B', name: 'Boro', electronegativity: 2.04, isMetal: false, atomicRadius: 87.0, atomicWeight: 10.81, valences: [3]),
  Element(atomicNumber: 6, symbol: 'C', name: 'Carbono', electronegativity: 2.55, isMetal: false, atomicRadius: 67.0, atomicWeight: 12.011, valences: [4]),
  Element(atomicNumber: 7, symbol: 'N', name: 'Nitrógeno', electronegativity: 3.04, isMetal: false, atomicRadius: 56.0, atomicWeight: 14.007, valences: [3]),
  Element(atomicNumber: 8, symbol: 'O', name: 'Oxígeno', electronegativity: 3.44, isMetal: false, atomicRadius: 48.0, atomicWeight: 15.999, valences: [2]),
  Element(atomicNumber: 9, symbol: 'F', name: 'Flúor', electronegativity: 3.98, isMetal: false, atomicRadius: 42.0, atomicWeight: 18.998, valences: [1]),
  Element(atomicNumber: 10, symbol: 'Ne', name: 'Neón', electronegativity: 0.0, isMetal: false, atomicRadius: 38.0, atomicWeight: 20.180, valences: [0]),
  Element(atomicNumber: 11, symbol: 'Na', name: 'Sodio', electronegativity: 0.93, isMetal: true, atomicRadius: 190.0, atomicWeight: 22.990, valences: [1]),
  Element(atomicNumber: 12, symbol: 'Mg', name: 'Magnesio', electronegativity: 1.31, isMetal: true, atomicRadius: 145.0, atomicWeight: 24.305, valences: [2]),
  Element(atomicNumber: 13, symbol: 'Al', name: 'Aluminio', electronegativity: 1.61, isMetal: true, atomicRadius: 118.0, atomicWeight: 26.982, valences: [3]),
  Element(atomicNumber: 14, symbol: 'Si', name: 'Silicio', electronegativity: 1.90, isMetal: false, atomicRadius: 111.0, atomicWeight: 28.085, valences: [4]),
  Element(atomicNumber: 15, symbol: 'P', name: 'Fósforo', electronegativity: 2.19, isMetal: false, atomicRadius: 98.0, atomicWeight: 30.974, valences: [3, 5]),
  Element(atomicNumber: 16, symbol: 'S', name: 'Azufre', electronegativity: 2.58, isMetal: false, atomicRadius: 88.0, atomicWeight: 32.06, valences: [2, 4, 6]),
  Element(atomicNumber: 17, symbol: 'Cl', name: 'Cloro', electronegativity: 3.16, isMetal: false, atomicRadius: 79.0, atomicWeight: 35.453, valences: [1]),
  Element(atomicNumber: 18, symbol: 'Ar', name: 'Argón', electronegativity: 0.0, isMetal: false, atomicRadius: 71.0, atomicWeight: 39.948, valences: [0]),
  Element(atomicNumber: 19, symbol: 'K', name: 'Potasio', electronegativity: 0.82, isMetal: true, atomicRadius: 243.0, atomicWeight: 39.098, valences: [1]),
  Element(atomicNumber: 20, symbol: 'Ca', name: 'Calcio', electronegativity: 1.00, isMetal: true, atomicRadius: 194.0, atomicWeight: 40.078, valences: [2]),
  Element(atomicNumber: 21, symbol: 'Sc', name: 'Escandio', electronegativity: 1.36, isMetal: true, atomicRadius: 162.0, atomicWeight: 44.956, valences: [3]),
  Element(atomicNumber: 22, symbol: 'Ti', name: 'Titanio', electronegativity: 1.54, isMetal: true, atomicRadius: 147.0, atomicWeight: 47.867, valences: [4]),
  Element(atomicNumber: 23, symbol: 'V', name: 'Vanadio', electronegativity: 1.63, isMetal: true, atomicRadius: 134.0, atomicWeight: 50.942, valences: [5]),
  Element(atomicNumber: 24, symbol: 'Cr', name: 'Cromo', electronegativity: 1.66, isMetal: true, atomicRadius: 124.0, atomicWeight: 51.996, valences: [6, 3]),
  Element(atomicNumber: 25, symbol: 'Mn', name: 'Manganeso', electronegativity: 1.55, isMetal: true, atomicRadius: 112.0, atomicWeight: 54.938, valences: [2, 4, 7]),
  Element(atomicNumber: 26, symbol: 'Fe', name: 'Hierro', electronegativity: 1.83, isMetal: true, atomicRadius: 117.0, atomicWeight: 55.845, valences: [2, 3]),
  Element(atomicNumber: 27, symbol: 'Co', name: 'Cobalto', electronegativity: 1.88, isMetal: true, atomicRadius: 125.0, atomicWeight: 58.933, valences: [2, 3]),
  Element(atomicNumber: 28, symbol: 'Ni', name: 'Níquel', electronegativity: 1.91, isMetal: true, atomicRadius: 124.0, atomicWeight: 58.693, valences: [2]),
  Element(atomicNumber: 29, symbol: 'Cu', name: 'Cobre', electronegativity: 1.90, isMetal: true, atomicRadius: 128.0, atomicWeight: 63.546, valences: [1, 2]),
  Element(atomicNumber: 30, symbol: 'Zn', name: 'Cinc', electronegativity: 1.65, isMetal: true, atomicRadius: 134.0, atomicWeight: 65.38, valences: [2]),
  Element(atomicNumber: 31, symbol: 'Ga', name: 'Galio', electronegativity: 1.81, isMetal: true, atomicRadius: 136.0, atomicWeight: 69.723, valences: [3]),
  Element(atomicNumber: 32, symbol: 'Ge', name: 'Germanio', electronegativity: 2.01, isMetal: false, atomicRadius: 122.0, atomicWeight: 72.630, valences: [4]),
  Element(atomicNumber: 33, symbol: 'As', name: 'Arsénico', electronegativity: 2.18, isMetal: false, atomicRadius: 119.0, atomicWeight: 74.922, valences: [3, 5]),
  Element(atomicNumber: 34, symbol: 'Se', name: 'Selenio', electronegativity: 2.55, isMetal: false, atomicRadius: 120.0, atomicWeight: 78.971, valences: [2, 4, 6]),
  Element(atomicNumber: 35, symbol: 'Br', name: 'Bromo', electronegativity: 2.96, isMetal: false, atomicRadius: 114.0, atomicWeight: 79.904, valences: [1]),
  Element(atomicNumber: 36, symbol: 'Kr', name: 'Kriptón', electronegativity: 3.00, isMetal: false, atomicRadius: 88.0, atomicWeight: 83.798, valences: [0]),
  Element(atomicNumber: 37, symbol: 'Rb', name: 'Rubidio', electronegativity: 0.82, isMetal: true, atomicRadius: 265.0, atomicWeight: 85.468, valences: [1]),
  Element(atomicNumber: 38, symbol: 'Sr', name: 'Estroncio', electronegativity: 0.95, isMetal: true, atomicRadius: 219.0, atomicWeight: 87.62, valences: [2]),
  Element(atomicNumber: 39, symbol: 'Y', name: 'Itrio', electronegativity: 1.22, isMetal: true, atomicRadius: 190.0, atomicWeight: 88.906, valences: [3]),
  Element(atomicNumber: 40, symbol: 'Zr', name: 'Circonio', electronegativity: 1.33, isMetal: true, atomicRadius: 175.0, atomicWeight: 91.224, valences: [4]),
  Element(atomicNumber: 41, symbol: 'Nb', name: 'Niobio', electronegativity: 1.60, isMetal: true, atomicRadius: 147.0, atomicWeight: 92.906, valences: [5]),
  Element(atomicNumber: 42, symbol: 'Mo', name: 'Molibdeno', electronegativity: 2.16, isMetal: true, atomicRadius: 139.0, atomicWeight: 95.95, valences: [6]),
  Element(atomicNumber: 43, symbol: 'Tc', name: 'Tecnecio', electronegativity: 1.90, isMetal: true, atomicRadius: 139.0, atomicWeight: 98.0, valences: [7, 4]),
  Element(atomicNumber: 44, symbol: 'Ru', name: 'Rutenio', electronegativity: 2.20, isMetal: true, atomicRadius: 139.0, atomicWeight: 101.07, valences: [4, 3]),
  Element(atomicNumber: 45, symbol: 'Rh', name: 'Rodio', electronegativity: 2.28, isMetal: true, atomicRadius: 145.0, atomicWeight: 102.91, valences: [3]),
  Element(atomicNumber: 46, symbol: 'Pd', name: 'Paladio', electronegativity: 2.20, isMetal: true, atomicRadius: 159.0, atomicWeight: 106.42, valences: [2]),
  Element(atomicNumber: 47, symbol: 'Ag', name: 'Plata', electronegativity: 1.93, isMetal: true, atomicRadius: 165.0, atomicWeight: 107.87, valences: [1]),
  Element(atomicNumber: 48, symbol: 'Cd', name: 'Cadmio', electronegativity: 1.69, isMetal: true, atomicRadius: 184.0, atomicWeight: 112.41, valences: [2]),
  Element(atomicNumber: 49, symbol: 'In', name: 'Indio', electronegativity: 1.78, isMetal: true, atomicRadius: 193.0, atomicWeight: 114.82, valences: [3]),
  Element(atomicNumber: 50, symbol: 'Sn', name: 'Estaño', electronegativity: 1.96, isMetal: true, atomicRadius: 139.0, atomicWeight: 118.71, valences: [2, 4]),
  Element(atomicNumber: 51, symbol: 'Sb', name: 'Antimonio', electronegativity: 2.05, isMetal: false, atomicRadius: 139.0, atomicWeight: 121.76, valences: [3, 5]),
  Element(atomicNumber: 52, symbol: 'Te', name: 'Telurio', electronegativity: 2.10, isMetal: false, atomicRadius: 142.0, atomicWeight: 127.60, valences: [2, 4, 6]),
  Element(atomicNumber: 53, symbol: 'I', name: 'Yodo', electronegativity: 2.66, isMetal: false, atomicRadius: 115.0, atomicWeight: 126.90, valences: [1]),
  Element(atomicNumber: 54, symbol: 'Xe', name: 'Xenón', electronegativity: 2.60, isMetal: false, atomicRadius: 108.0, atomicWeight: 131.29, valences: [0]),
  Element(atomicNumber: 55, symbol: 'Cs', name: 'Cesio', electronegativity: 0.79, isMetal: true, atomicRadius: 298.0, atomicWeight: 132.91, valences: [1]),
  Element(atomicNumber: 56, symbol: 'Ba', name: 'Bario', electronegativity: 0.89, isMetal: true, atomicRadius: 253.0, atomicWeight: 137.33, valences: [2]),
  Element(atomicNumber: 57, symbol: 'La', name: 'Lantano', electronegativity: 1.10, isMetal: true, atomicRadius: 195.0, atomicWeight: 138.91, valences: [3]),
  Element(atomicNumber: 58, symbol: 'Ce', name: 'Cerio', electronegativity: 1.12, isMetal: true, atomicRadius: 162.0, atomicWeight: 140.12, valences: [3, 4]),
  Element(atomicNumber: 59, symbol: 'Pr', name: 'Praseodimio', electronegativity: 1.13, isMetal: true, atomicRadius: 182.0, atomicWeight: 140.91, valences: [3]),
  Element(atomicNumber: 60, symbol: 'Nd', name: 'Neodimio', electronegativity: 1.14, isMetal: true, atomicRadius: 182.0, atomicWeight: 144.24, valences: [3]),
  Element(atomicNumber: 61, symbol: 'Pm', name: 'Prometio', electronegativity: 1.13, isMetal: true, atomicRadius: 183.0, atomicWeight: 145.0, valences: [3]),
  Element(atomicNumber: 62, symbol: 'Sm', name: 'Samario', electronegativity: 1.17, isMetal: true, atomicRadius: 181.0, atomicWeight: 150.36, valences: [2, 3]),
  Element(atomicNumber: 63, symbol: 'Eu', name: 'Europio', electronegativity: 1.20, isMetal: true, atomicRadius: 185.0, atomicWeight: 151.96, valences: [2, 3]),
  Element(atomicNumber: 64, symbol: 'Gd', name: 'Gadolinio', electronegativity: 1.20, isMetal: true, atomicRadius: 179.0, atomicWeight: 157.25, valences: [3]),
  Element(atomicNumber: 65, symbol: 'Tb', name: 'Terbio', electronegativity: 1.10, isMetal: true, atomicRadius: 176.0, atomicWeight: 158.93, valences: [3]),
  Element(atomicNumber: 66, symbol: 'Dy', name: 'Disprosio', electronegativity: 1.22, isMetal: true, atomicRadius: 178.0, atomicWeight: 162.50, valences: [3]),
  Element(atomicNumber: 67, symbol: 'Ho', name: 'Holmio', electronegativity: 1.23, isMetal: true, atomicRadius: 177.0, atomicWeight: 164.93, valences: [3]),
  Element(atomicNumber: 68, symbol: 'Er', name: 'Erbio', electronegativity: 1.24, isMetal: true, atomicRadius: 176.0, atomicWeight: 167.26, valences: [3]),
  Element(atomicNumber: 69, symbol: 'Tm', name: 'Tulio', electronegativity: 1.25, isMetal: true, atomicRadius: 175.0, atomicWeight: 168.93, valences: [3]),
  Element(atomicNumber: 70, symbol: 'Yb', name: 'Iterbio', electronegativity: 1.10, isMetal: true, atomicRadius: 194.0, atomicWeight: 173.05, valences: [2, 3]),
  Element(atomicNumber: 71, symbol: 'Lu', name: 'Lutecio', electronegativity: 1.27, isMetal: true, atomicRadius: 173.0, atomicWeight: 174.97, valences: [3]),
  Element(atomicNumber: 72, symbol: 'Hf', name: 'Hafnio', electronegativity: 1.30, isMetal: true, atomicRadius: 159.0, atomicWeight: 178.49, valences: [4]),
  Element(atomicNumber: 73, symbol: 'Ta', name: 'Tantalio', electronegativity: 1.50, isMetal: true, atomicRadius: 147.0, atomicWeight: 180.95, valences: [5]),
  Element(atomicNumber: 74, symbol: 'W', name: 'Tungsteno', electronegativity: 2.36, isMetal: true, atomicRadius: 141.0, atomicWeight: 183.84, valences: [6]),
  Element(atomicNumber: 75, symbol: 'Re', name: 'Renio', electronegativity: 1.90, isMetal: true, atomicRadius: 137.0, atomicWeight: 186.21, valences: [7]),
  Element(atomicNumber: 76, symbol: 'Os', name: 'Osmio', electronegativity: 2.20, isMetal: true, atomicRadius: 135.0, atomicWeight: 190.23, valences: [4, 8]),
  Element(atomicNumber: 77, symbol: 'Ir', name: 'Iridio', electronegativity: 2.20, isMetal: true, atomicRadius: 136.0, atomicWeight: 192.22, valences: [3, 4]),
  Element(atomicNumber: 78, symbol: 'Pt', name: 'Platino', electronegativity: 2.28, isMetal: true, atomicRadius: 139.0, atomicWeight: 195.08, valences: [2, 4]),
  Element(atomicNumber: 79, symbol: 'Au', name: 'Oro', electronegativity: 2.54, isMetal: true, atomicRadius: 144.0, atomicWeight: 196.97, valences: [1, 3]),
  Element(atomicNumber: 80, symbol: 'Hg', name: 'Mercurio', electronegativity: 2.00, isMetal: true, atomicRadius: 150.0, atomicWeight: 200.59, valences: [1, 2]),
  Element(atomicNumber: 81, symbol: 'Tl', name: 'Talio', electronegativity: 1.62, isMetal: true, atomicRadius: 196.0, atomicWeight: 204.38, valences: [1, 3]),
  Element(atomicNumber: 82, symbol: 'Pb', name: 'Plomo', electronegativity: 2.33, isMetal: true, atomicRadius: 154.0, atomicWeight: 207.2, valences: [2, 4]),
  Element(atomicNumber: 83, symbol: 'Bi', name: 'Bismuto', electronegativity: 2.02, isMetal: true, atomicRadius: 155.0, atomicWeight: 208.98, valences: [3, 5]),
  Element(atomicNumber: 84, symbol: 'Po', name: 'Polonio', electronegativity: 2.00, isMetal: false, atomicRadius: 167.0, atomicWeight: 209.0, valences: [2, 4, 6]),
  Element(atomicNumber: 85, symbol: 'At', name: 'Astato', electronegativity: 2.20, isMetal: false, atomicRadius: 140.0, atomicWeight: 210.0, valences: [1]),
  Element(atomicNumber: 86, symbol: 'Rn', name: 'Radón', electronegativity: 2.20, isMetal: false, atomicRadius: 120.0, atomicWeight: 222.0, valences: [0]),
  Element(atomicNumber: 87, symbol: 'Fr', name: 'Francio', electronegativity: 0.70, isMetal: true, atomicRadius: 270.0, atomicWeight: 223.0, valences: [1]),
  Element(atomicNumber: 88, symbol: 'Ra', name: 'Radio', electronegativity: 0.90, isMetal: true, atomicRadius: 221.0, atomicWeight: 226.0, valences: [2]),
  Element(atomicNumber: 89, symbol: 'Ac', name: 'Actinio', electronegativity: 1.10, isMetal: true, atomicRadius: 190.0, atomicWeight: 227.0, valences: [3]),
  Element(atomicNumber: 90, symbol: 'Th', name: 'Torio', electronegativity: 1.30, isMetal: true, atomicRadius: 180.0, atomicWeight: 232.04, valences: [4]),
  Element(atomicNumber: 91, symbol: 'Pa', name: 'Protactinio', electronegativity: 1.50, isMetal: true, atomicRadius: 161.0, atomicWeight: 231.04, valences: [5]),
  Element(atomicNumber: 92, symbol: 'U', name: 'Uranio', electronegativity: 1.38, isMetal: true, atomicRadius: 150.0, atomicWeight: 238.03, valences: [6, 5, 4]),
  Element(atomicNumber: 93, symbol: 'Np', name: 'Neptunio', electronegativity: 1.36, isMetal: true, atomicRadius: 130.0, atomicWeight: 237.0, valences: [5, 4]),
  Element(atomicNumber: 94, symbol: 'Pu', name: 'Plutonio', electronegativity: 1.28, isMetal: true, atomicRadius: 151.0, atomicWeight: 244.0, valences: [4, 3]),
  Element(atomicNumber: 95, symbol: 'Am', name: 'Americio', electronegativity: 1.13, isMetal: true, atomicRadius: 173.0, atomicWeight: 243.0, valences: [3]),
  Element(atomicNumber: 96, symbol: 'Cm', name: 'Curio', electronegativity: 1.13, isMetal: true, atomicRadius: 169.0, atomicWeight: 247.0, valences: [3]),
  Element(atomicNumber: 97, symbol: 'Bk', name: 'Berkelio', electronegativity: 1.30, isMetal: true, atomicRadius: 167.0, atomicWeight: 247.0, valences: [3]),
  Element(atomicNumber: 98, symbol: 'Cf', name: 'Californio', electronegativity: 1.30, isMetal: true, atomicRadius: 168.0, atomicWeight: 251.0, valences: [3]),
  Element(atomicNumber: 99, symbol: 'Es', name: 'Einstenio', electronegativity: 1.30, isMetal: true, atomicRadius: 165.0, atomicWeight: 252.0, valences: [3]),
  Element(atomicNumber: 100, symbol: 'Fm', name: 'Fermio', electronegativity: 1.30, isMetal: true, atomicRadius: 167.0, atomicWeight: 257.0, valences: [3]),
  Element(atomicNumber: 101, symbol: 'Md', name: 'Mendelevio', electronegativity: 1.30, isMetal: true, atomicRadius: 173.0, atomicWeight: 258.0, valences: [2, 3]),
  Element(atomicNumber: 102, symbol: 'No', name: 'Nobelio', electronegativity: 1.30, isMetal: true, atomicRadius: 176.0, atomicWeight: 259.0, valences: [2, 3]),
  Element(atomicNumber: 103, symbol: 'Lr', name: 'Laurencio', electronegativity: 1.30, isMetal: true, atomicRadius: 161.0, atomicWeight: 262.0, valences: [3]),
  Element(atomicNumber: 104, symbol: 'Rf', name: 'Rutherfordio', electronegativity: 1.30, isMetal: true, atomicRadius: 157.0, atomicWeight: 267.0, valences: [4]),
  Element(atomicNumber: 105, symbol: 'Db', name: 'Dubnio', electronegativity: 0.0, isMetal: true, atomicRadius: 149.0, atomicWeight: 268.0, valences: [5]),
  Element(atomicNumber: 106, symbol: 'Sg', name: 'Seaborgio', electronegativity: 0.0, isMetal: true, atomicRadius: 143.0, atomicWeight: 269.0, valences: [6]),
  Element(atomicNumber: 107, symbol: 'Bh', name: 'Bohrio', electronegativity: 0.0, isMetal: true, atomicRadius: 141.0, atomicWeight: 270.0, valences: [7]),
  Element(atomicNumber: 108, symbol: 'Hs', name: 'Hasio', electronegativity: 0.0, isMetal: true, atomicRadius: 134.0, atomicWeight: 269.0, valences: [8]),
  Element(atomicNumber: 109, symbol: 'Mt', name: 'Meitnerio', electronegativity: 0.0, isMetal: true, atomicRadius: 129.0, atomicWeight: 278.0, valences: [9]),
  Element(atomicNumber: 110, symbol: 'Ds', name: 'Darmstadtio', electronegativity: 0.0, isMetal: true, atomicRadius: 122.0, atomicWeight: 281.0, valences: [0]),
  Element(atomicNumber: 111, symbol: 'Rg', name: 'Roentgenio', electronegativity: 0.0, isMetal: true, atomicRadius: 121.0, atomicWeight: 281.0, valences: [0]),
  Element(atomicNumber: 112, symbol: 'Cn', name: 'Copernicio', electronegativity: 0.0, isMetal: true, atomicRadius: 122.0, atomicWeight: 285.0, valences: [2]),
  Element(atomicNumber: 113, symbol: 'Nh', name: 'Nihonio', electronegativity: 0.0, isMetal: false, atomicRadius: 136.0, atomicWeight: 286.0, valences: [3]),
  Element(atomicNumber: 114, symbol: 'Fl', name: 'Flerovio', electronegativity: 0.0, isMetal: false, atomicRadius: 143.0, atomicWeight: 289.0, valences: [4]),
  Element(atomicNumber: 115, symbol: 'Mc', name: 'Moscovio', electronegativity: 0.0, isMetal: false, atomicRadius: 162.0, atomicWeight: 289.0, valences: [3]),
  Element(atomicNumber: 116, symbol: 'Lv', name: 'Livermorio', electronegativity: 0.0, isMetal: false, atomicRadius: 175.0, atomicWeight: 293.0, valences: [2]),
  Element(atomicNumber: 117, symbol: 'Ts', name: 'Teneso', electronegativity: 0.0, isMetal: false, atomicRadius: 138.0, atomicWeight: 294.0, valences: [1]),
  Element(atomicNumber: 118, symbol: 'Og', name: 'Oganesón', electronegativity: 0.0, isMetal: false, atomicRadius: 157.0, atomicWeight: 294.0, valences: [0]),
];

// Mapeo para nombres de enlaces
final Map<String, String> bondTypeMap = {
  'covalente-no-polar': 'Enlace Covalente No Polar',
  'covalente-polar': 'Enlace Covalente Polar',
  'ionico': 'Enlace Iónico',
  'metalico': 'Enlace Metálico',
};

// Base de datos de moléculas
final List<Map<String, dynamic>> moleculeDatabase = [
  {
    'name': 'Agua',
    'formula': 'H2O',
    'composition': {'H': 2, 'O': 1},
  },
  {
    'name': 'Dióxido de carbono',
    'formula': 'CO2',
    'composition': {'C': 1, 'O': 2},
  },
  {
    'name': 'Cloruro de sodio',
    'formula': 'NaCl',
    'composition': {'Na': 1, 'Cl': 1},
  },
  {
    'name': 'Metano',
    'formula': 'CH4',
    'composition': {'C': 1, 'H': 4},
  },
  {
    'name': 'Amoníaco',
    'formula': 'NH3',
    'composition': {'N': 1, 'H': 3},
  },
  {
    'name': 'Ácido Sulfúrico',
    'formula': 'H2SO4',
    'composition': {'H': 2, 'S': 1, 'O': 4},
  },
  {
    'name': 'Benceno',
    'formula': 'C6H6',
    'composition': {'C': 6, 'H': 6},
  },
  {
    'name': 'Óxido de Magnesio',
    'formula': 'MgO',
    'composition': {'Mg': 1, 'O': 1},
  },
  {
    'name': 'Ozono',
    'formula': 'O3',
    'composition': {'O': 3},
  },
  {
    'name': 'Peróxido de Hidrógeno',
    'formula': 'H2O2',
    'composition': {'H': 2, 'O': 2},
  },
  {
    'name': 'Cloroformo',
    'formula': 'CHCl3',
    'composition': {'C': 1, 'H': 1, 'Cl': 3},
  },
  {
    'name': 'Etanol',
    'formula': 'C2H5OH',
    'composition': {'C': 2, 'H': 6, 'O': 1},
  },
  {
    'name': 'Ácido Clorhídrico',
    'formula': 'HCl',
    'composition': {'H': 1, 'Cl': 1},
  },
  {
    'name': 'Propano',
    'formula': 'C3H8',
    'composition': {'C': 3, 'H': 8},
  },
  {
    'name': 'Butano',
    'formula': 'C4H10',
    'composition': {'C': 4, 'H': 10},
  },
  {
    'name': 'Ácido Nítrico',
    'formula': 'HNO3',
    'composition': {'H': 1, 'N': 1, 'O': 3},
  },
  {
    'name': 'Glucosa',
    'formula': 'C6H12O6',
    'composition': {'C': 6, 'H': 12, 'O': 6},
  },
  {
    'name': 'Acetona',
    'formula': 'C3H6O',
    'composition': {'C': 3, 'H': 6, 'O': 1},
  },
  {
    'name': 'Propanol',
    'formula': 'C3H8O',
    'composition': {'C': 3, 'H': 8, 'O': 1},
  },
  {
    'name': 'Dióxido de Azufre',
    'formula': 'SO2',
    'composition': {'S': 1, 'O': 2},
  },
  // Nuevas moléculas añadidas
  {
    'name': 'Etano',
    'formula': 'C2H6',
    'composition': {'C': 2, 'H': 6},
  },
  {
    'name': 'Ácido Acético',
    'formula': 'CH3COOH',
    'composition': {'C': 2, 'H': 4, 'O': 2},
  },
  {
    'name': 'Metanol',
    'formula': 'CH3OH',
    'composition': {'C': 1, 'H': 4, 'O': 1},
  },
  {
    'name': 'Peróxido de Hidrógeno',
    'formula': 'H2O2',
    'composition': {'H': 2, 'O': 2},
  },
  {
    'name': 'Hexano',
    'formula': 'C6H14',
    'composition': {'C': 6, 'H': 14},
  },
  {
    'name': 'Sulfuro de hidrógeno',
    'formula': 'H2S',
    'composition': {'H': 2, 'S': 1},
  },
  {
    'name': 'Ácido Clórico',
    'formula': 'HClO3',
    'composition': {'H': 1, 'Cl': 1, 'O': 3},
  },
  {
    'name': 'Ácido Fosfórico',
    'formula': 'H3PO4',
    'composition': {'H': 3, 'P': 1, 'O': 4},
  },
  {
    'name': 'Bromuro de Litio',
    'formula': 'LiBr',
    'composition': {'Li': 1, 'Br': 1},
  },
  {
    'name': 'Fluoruro de Calcio',
    'formula': 'CaF2',
    'composition': {'Ca': 1, 'F': 2},
  },
  {
    'name': 'Yoduro de Potasio',
    'formula': 'KI',
    'composition': {'K': 1, 'I': 1},
  },
  {
    'name': 'Bióxido de Titanio',
    'formula': 'TiO2',
    'composition': {'Ti': 1, 'O': 2},
  },
  {
    'name': 'Diborano',
    'formula': 'B2H6',
    'composition': {'B': 2, 'H': 6},
  },
  {
    'name': 'Ácido Cianhídrico',
    'formula': 'HCN',
    'composition': {'H': 1, 'C': 1, 'N': 1},
  },
  {
    'name': 'Sulfato de Cobre(II)',
    'formula': 'CuSO4',
    'composition': {'Cu': 1, 'S': 1, 'O': 4},
  },
  {
    'name': 'Carbonato de Calcio',
    'formula': 'CaCO3',
    'composition': {'Ca': 1, 'C': 1, 'O': 3},
  },
  {
    'name': 'Óxido de Hierro(III)',
    'formula': 'Fe2O3',
    'composition': {'Fe': 2, 'O': 3},
  },
  {
    'name': 'Ácido Bromhídrico',
    'formula': 'HBr',
    'composition': {'H': 1, 'Br': 1},
  },
];

void main() {
  periodicTable.sort((a, b) => a.atomicWeight.compareTo(b.atomicWeight));
  runApp(const SimulatorApp());
}

class SimulatorApp extends StatelessWidget {
  const SimulatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simulador Atómico',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SimulatorScreen(),
    );
  }
}

class SimulatorScreen extends StatefulWidget {
  const SimulatorScreen({super.key});

  @override
  State<SimulatorScreen> createState() => _SimulatorScreenState();
}

class _SimulatorScreenState extends State<SimulatorScreen> with TickerProviderStateMixin {
  late final PhysicsEngine _physicsEngine;
  late final AnimationController _animationController;
  final List<String> _formedBonds = [];
  int _moleculeCount = 0;
  EnvironmentState _currentEnvironment = EnvironmentState.idealAbstract;
  Size _simulationAreaSize = Size.zero;
  final ValueNotifier<Atom?> _selectedAtomNotifier = ValueNotifier(null);
  final ValueNotifier<Element?> _hoveredElementNotifier = ValueNotifier(null);
  double _electronSpeedFactor = 0.05;
  double _orbitExpansionFactor = 1.0;
  ExperimentMode _currentMode = ExperimentMode.free;
  Map<String, dynamic>? _currentMolecule;
  bool _moleculeFormed = false;
  bool _isCompositionComplete = false;
  bool _showSuccessMessage = false;

  @override
  void initState() {
    super.initState();
    _physicsEngine = PhysicsEngine(constants: EnvironmentConstants.idealAbstract);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(() {
      if (_simulationAreaSize != Size.zero) {
        if (_currentMode == ExperimentMode.guided && !_isCompositionComplete) {
          _checkCompositionStatus();
        }
        _physicsEngine.update(_simulationAreaSize);
        for (var atom in _physicsEngine.atoms) {
          for (int i = 0; i < atom.electronAngles.length; i++) {
            atom.electronAngles[i] += _electronSpeedFactor;
            if (atom.electronAngles[i] > 2 * pi) {
              atom.electronAngles[i] -= 2 * pi;
            }
          }
        }
        _checkNewBonds();
        _checkNewMolecules();
        if (_currentMode == ExperimentMode.guided) {
          _checkIfMoleculeFormed();
        }
      }
      setState(() {});
    })..repeat();
  }

  void _checkNewBonds() {
    for (var atom in _physicsEngine.atoms) {
      for (var bondedAtom in atom.bondedTo) {
        final bondDescription = '${atom.element.symbol}-${bondedAtom.element.symbol}';
        final reverseDescription = '${bondedAtom.element.symbol}-${atom.element.symbol}';
        if (!_formedBonds.contains(bondDescription) && !_formedBonds.contains(reverseDescription)) {
          final bondType = ChemRuleEngine.getBondType(atom.element, bondedAtom.element);
          _formedBonds.add('$bondDescription ($bondType)');
          if (_formedBonds.length > 2) {
            _formedBonds.removeAt(0);
          }
        }
      }
    }
  }

  void _checkNewMolecules() {
    Set<int> processedAtomIds = {};
    int count = 0;
    
    for (var atom in _physicsEngine.atoms) {
      if (!processedAtomIds.contains(atom.id)) {
        List<Atom> molecule = _findConnectedComponent(atom, processedAtomIds);
        if (molecule.length > 1) {
          count++;
        }
      }
    }
    setState(() {
      _moleculeCount = count;
    });
  }

  List<Atom> _findConnectedComponent(Atom startAtom, Set<int> processedAtomIds) {
    List<Atom> component = [];
    List<Atom> queue = [startAtom];
    processedAtomIds.add(startAtom.id);
    
    while (queue.isNotEmpty) {
      Atom current = queue.removeAt(0);
      component.add(current);
      
      for (var neighbor in current.bondedTo) {
        if (!processedAtomIds.contains(neighbor.id)) {
          processedAtomIds.add(neighbor.id);
          queue.add(neighbor);
        }
      }
    }
    return component;
  }

  void _checkCompositionStatus() {
    if (_currentMolecule == null) return;
    
    final required = _currentMolecule!['composition'] as Map<String, int>;
    bool allPresent = true;
    
    for (var symbol in required.keys) {
      final currentCount = _physicsEngine.elementGroups[symbol]?.length ?? 0;
      if (currentCount < required[symbol]!) {
        allPresent = false;
        break;
      }
    }

    if (allPresent && !_isCompositionComplete) {
      setState(() {
        _isCompositionComplete = true;
        _setEnvironment(EnvironmentState.stableAbstract);
      });
    } else if (!allPresent && _isCompositionComplete) {
      setState(() {
        _isCompositionComplete = false;
        _setEnvironment(EnvironmentState.idealAbstract);
      });
    }
  }


  void _checkIfMoleculeFormed() {
    if (_currentMolecule == null || _moleculeFormed) return;

    Set<int> processedAtomIds = {};
    for (var atom in _physicsEngine.atoms) {
      if (!processedAtomIds.contains(atom.id)) {
        List<Atom> molecule = _findConnectedComponent(atom, processedAtomIds);
        if (molecule.length == _physicsEngine.atoms.length) {
          Map<String, int> currentComposition = {};
          for (var a in molecule) {
            currentComposition.update(a.element.symbol, (v) => v + 1, ifAbsent: () => 1);
          }
          bool compositionMatches = _compareMaps(currentComposition, _currentMolecule!['composition']);
          if (compositionMatches) {
            setState(() {
              _moleculeFormed = true;
              _showSuccessMessage = true;
            });
            break;
          }
        }
      }
    }
  }

  // Nueva función para comparar mapas de composición
  bool _compareMaps(Map<String, int> map1, Map<String, int> map2) {
    if (map1.length != map2.length) return false;
    for (final key in map1.keys) {
      if (!map2.containsKey(key) || map1[key] != map2[key]) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _animationController.dispose();
    _selectedAtomNotifier.dispose();
    _hoveredElementNotifier.dispose();
    super.dispose();
  }

  void _addElement(Element element) {
    if (_simulationAreaSize != Size.zero) {
      if (_currentMode == ExperimentMode.guided && _currentMolecule != null) {
        final symbol = element.symbol;
        final required = _currentMolecule!['composition'] as Map<String, int>;
        final currentCount = _physicsEngine.elementGroups[symbol]?.length ?? 0;
        if (required.containsKey(symbol) && currentCount < required[symbol]!) {
          setState(() {
            _physicsEngine.addAtom(element, _simulationAreaSize);
            _initializeElectronState(_physicsEngine.atoms.last);
          });
        }
      } else if (_currentMode == ExperimentMode.free) {
        setState(() {
          _physicsEngine.addAtom(element, _simulationAreaSize);
          _initializeElectronState(_physicsEngine.atoms.last);
        });
      }
    }
  }

  void _initializeElectronState(Atom atom) {
    int electronsRemaining = atom.element.atomicNumber;
    final shells = [2, 8, 18, 32, 50, 72];
    double radiusIncrement = 20.0;
    double currentRadius = 15.0;

    for (var shellMax in shells) {
      if (electronsRemaining <= 0) break;
      int electronsInShell = min(electronsRemaining, shellMax);
      for (int i = 0; i < electronsInShell; i++) {
        atom.electronAngles.add(Random().nextDouble() * 2 * pi);
        atom.electronRadii.add(currentRadius);
      }
      electronsRemaining -= electronsInShell;
      currentRadius += radiusIncrement;
    }
  }

  void _clearSimulation() {
    setState(() {
      _physicsEngine.clear();
      _formedBonds.clear();
      _moleculeCount = 0;
      _selectedAtomNotifier.value = null;
      _moleculeFormed = false;
      _isCompositionComplete = false;
      _showSuccessMessage = false;
    });
  }

  void _setEnvironment(EnvironmentState state) {
    setState(() {
      _currentEnvironment = state;
      switch (state) {
        case EnvironmentState.idealAbstract:
          _physicsEngine.setEnvironment(EnvironmentConstants.idealAbstract);
          _electronSpeedFactor = 0.05;
          _orbitExpansionFactor = 1.0;
          break;
        case EnvironmentState.realAbstract:
          _physicsEngine.setEnvironment(EnvironmentConstants.realAbstract);
          _electronSpeedFactor = 0.15;
          _orbitExpansionFactor = 1.5;
          break;
        case EnvironmentState.stableAbstract:
          _physicsEngine.setEnvironment(EnvironmentConstants.stableAbstract);
          _electronSpeedFactor = 0.05;
          _orbitExpansionFactor = 1.0;
          break;
      }
      _physicsEngine.centralAttractionMultiplier = (_currentMode == ExperimentMode.guided) ? 5.0 : 1.0;
    });
  }

  void _setMode(ExperimentMode mode) {
    setState(() {
      _currentMode = mode;
      if (mode == ExperimentMode.guided) {
        _currentEnvironment = EnvironmentState.idealAbstract;
        _physicsEngine.setEnvironment(EnvironmentConstants.idealAbstract);
        _physicsEngine.centralAttractionMultiplier = 5.0; // AUMENTADO: Fuerza de atracción al centro
        _electronSpeedFactor = 0.05;
        _orbitExpansionFactor = 1.0;
        _selectNextMolecule();
      } else {
        _physicsEngine.centralAttractionMultiplier = 1.0;
      }
      _clearSimulation();
    });
  }

  void _selectNextMolecule() {
    _clearSimulation();
    setState(() {
      final randomIndex = Random().nextInt(moleculeDatabase.length);
      _currentMolecule = moleculeDatabase[randomIndex];
      _moleculeFormed = false;
      _isCompositionComplete = false;
      _showSuccessMessage = false;
      _setEnvironment(EnvironmentState.idealAbstract);
    });
  }

  String _getEnvironmentName(EnvironmentState state) {
    switch (state) {
      case EnvironmentState.idealAbstract:
        return 'Ideal Abstracto';
      case EnvironmentState.realAbstract:
        return 'Real Abstracto';
      case EnvironmentState.stableAbstract:
        return 'Enlace Estable';
    }
  }

  String _getModeName(ExperimentMode mode) {
    switch (mode) {
      case ExperimentMode.free:
        return 'Experimentación Libre';
      case ExperimentMode.guided:
        return 'Experimentación Guiada';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador de Enlaces Atómicos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _clearSimulation,
            tooltip: 'Reiniciar Simulación',
          ),
          PopupMenuButton<EnvironmentState>(
            initialValue: _currentEnvironment,
            onSelected: _currentMode == ExperimentMode.free ? _setEnvironment : null,
            itemBuilder: (BuildContext context) {
              return EnvironmentState.values.map((EnvironmentState state) {
                return PopupMenuItem<EnvironmentState>(
                  value: state,
                  child: Text(_getEnvironmentName(state)),
                );
              }).toList();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.settings),
                  const SizedBox(width: 8),
                  Text(_getEnvironmentName(_currentEnvironment)),
                ],
              ),
            ),
          ),
          PopupMenuButton<ExperimentMode>(
            initialValue: _currentMode,
            onSelected: _setMode,
            itemBuilder: (BuildContext context) {
              return ExperimentMode.values.map((ExperimentMode mode) {
                return PopupMenuItem<ExperimentMode>(
                  value: mode,
                  child: Text(_getModeName(mode)),
                );
              }).toList();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  const Icon(Icons.mode),
                  const SizedBox(width: 8),
                  Text(_getModeName(_currentMode)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _simulationAreaSize = constraints.biggest;
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                  ),
                  child: GestureDetector(
                    onTapUp: (details) {
                      Atom? tappedAtom = _findAtomAt(details.localPosition);
                      _selectedAtomNotifier.value = tappedAtom;
                    },
                    child: Stack(
                      children: [
                        CustomPaint(
                          painter: AtomPainter(
                            atoms: _physicsEngine.atoms,
                            selectedAtom: _selectedAtomNotifier.value,
                            orbitExpansionFactor: _orbitExpansionFactor,
                          ),
                          child: const SizedBox.expand(),
                        ),
                        _buildLegend(),
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Text(
                              'Moléculas: $_moleculeCount',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        if (_currentMode == ExperimentMode.guided && _currentMolecule != null && !_moleculeFormed)
                          Positioned(
                            top: 50,
                            right: 10,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8.0),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  child: Text(
                                    'Objetivo: ${_currentMolecule!['name']} (${_currentMolecule!['formula']})',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton.icon(
                                  onPressed: _selectNextMolecule,
                                  icon: const Icon(Icons.skip_next),
                                  label: const Text('Siguiente Molécula'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_showSuccessMessage)
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.all(12.0),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(10.0),
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '¡Molécula conformada!',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Has construido la molécula de ${_currentMolecule!['name']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'Fórmula: ${_currentMolecule!['formula']}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton(
                                    onPressed: _selectNextMolecule,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: Colors.green,
                                    ),
                                    child: const Text('Continuar'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.blue[50],
              child: Column(
                children: [
                  _buildElementTooltip(),
                  const SizedBox(height: 8.0),
                  _buildSelectedAtomPanel(),
                  const SizedBox(height: 8.0),
                  const Text(
                    'Selecciona elementos para simular',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8.0),
                  Expanded(
                    child: GridView.builder(
                      itemCount: periodicTable.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 13,
                        childAspectRatio: 0.9,
                        mainAxisSpacing: 4.0,
                        crossAxisSpacing: 4.0,
                      ),
                      itemBuilder: (context, index) {
                        final element = periodicTable[index];
                        int atomsRemaining = 0;
                        bool isEnabled = true;
                        if (_currentMode == ExperimentMode.guided && _currentMolecule != null) {
                          final required = _currentMolecule!['composition'] as Map<String, int>;
                          final currentCount = _physicsEngine.elementGroups[element.symbol]?.length ?? 0;
                          atomsRemaining = required.containsKey(element.symbol) ? required[element.symbol]! - currentCount : 0;
                          isEnabled = atomsRemaining > 0;
                        }

                        return MouseRegion(
                          onHover: (_) => _hoveredElementNotifier.value = element,
                          onExit: (_) => _hoveredElementNotifier.value = null,
                          child: SizedBox(
                            width: 30, // Tamaño fijo del botón
                            height: 30, // Tamaño fijo del botón
                            child: Stack(
                              children: [
                                ElevatedButton(
                                  onPressed: isEnabled ? () => _addElement(element) : null,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: ChemRuleEngine.getAtomColor(element),
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0)),
                                  ),
                                  child: Text(
                                    element.symbol,
                                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (atomsRemaining > 0)
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$atomsRemaining',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 16),
                  ValueListenableBuilder<List<String>>(
                    valueListenable: ValueNotifier(_formedBonds),
                    builder: (context, bonds, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Últimas uniones:',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 5),
                          ...bonds.map((bond) => Text(
                            '• $bond',
                            style: const TextStyle(fontSize: 12),
                          )).toList(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedAtomPanel() {
    return ValueListenableBuilder<Atom?>(
      valueListenable: _selectedAtomNotifier,
      builder: (context, atom, child) {
        if (atom == null) {
          return const Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(
                child: Text('Toca un átomo para ver sus detalles.'),
              ),
            ),
          );
        }
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Átomo: ${atom.element.name} (${atom.element.symbol})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('ID: ${atom.id}'),
                Text('Posición: (${atom.position.dx.toStringAsFixed(1)}, ${atom.position.dy.toStringAsFixed(1)})'),
                Text('Velocidad: (${atom.velocity.dx.toStringAsFixed(2)}, ${atom.velocity.dy.toStringAsFixed(2)})'),
                Text('Masa: ${atom.mass.toStringAsFixed(2)}'),
                Text('Enlaces Formados: ${atom.bondsFormed}'),
                Text('Tipo de Elemento: ${ChemRuleEngine.getElementType(atom.element)}'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildElementTooltip() {
    const emptyTooltipKey = ValueKey('empty_tooltip_placeholder');
    return SizedBox(
      height: 140,
      child: ValueListenableBuilder<Element?>(
        valueListenable: _hoveredElementNotifier,
        builder: (context, element, child) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: element == null
                ? const SizedBox.shrink(key: emptyTooltipKey)
                : Card(
                    key: ValueKey('info_card_${element.symbol}'),
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${element.name} (${element.symbol})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text('N° Atómico: ${element.atomicNumber}'),
                          Text('Electronegatividad: ${element.electronegativity}'),
                          Text('Radio Atómico: ${element.atomicRadius.toStringAsFixed(1)} pm'),
                          Text('Masa: ${element.atomicWeight} u'),
                          Text('Valencia: ${element.valences.join(', ')}'),
                        ],
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    return Positioned(
      bottom: 10,
      left: 10,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Leyenda de Enlaces',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _LegendItem(color: Colors.cyan, text: 'Iónico'),
            _LegendItem(color: Colors.lightGreenAccent, text: 'Covalente Polar'),
            _LegendItem(color: Colors.orange, text: 'Covalente No Polar'),
            _LegendItem(color: Colors.white, text: 'Metálico'),
            const SizedBox(height: 16),
            const Text(
              'Leyenda de Elementos',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _LegendItem(color: Colors.blue[800]!, text: 'Metales'),
            _LegendItem(color: Colors.orange[700]!, text: 'Semimetales'),
            _LegendItem(color: Colors.red[800]!, text: 'No Metales'),
          ],
        ),
      ),
    );
  }

  Atom? _findAtomAt(Offset position) {
    for (var atom in _physicsEngine.atoms) {
      final distance = (atom.position - position).distance;
      if (distance < atom.element.atomicRadius / 10) {
        return atom;
      }
    }
    return null;
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendItem({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}

class AtomPainter extends CustomPainter {
  final List<Atom> atoms;
  final Atom? selectedAtom;
  final double orbitExpansionFactor;

  AtomPainter({
    required this.atoms,
    this.selectedAtom,
    required this.orbitExpansionFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bondPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var atom in atoms) {
      for (var bondedAtom in atom.bondedTo) {
        final bondType = ChemRuleEngine.getBondType(atom.element, bondedAtom.element);
        switch (bondType) {
          case 'Enlace Iónico':
            bondPaint
              ..color = Colors.cyan
              ..strokeWidth = 3.0;
            canvas.drawLine(atom.position, bondedAtom.position, bondPaint);
            break;
          case 'Enlace Covalente Polar':
            bondPaint
              ..color = Colors.lightGreenAccent
              ..strokeWidth = 2.0;
            _drawDashedLine(canvas, atom.position, bondedAtom.position, bondPaint, dashLength: 10, spaceLength: 5);
            break;
          case 'Enlace Covalente No Polar':
            bondPaint
              ..color = Colors.orange
              ..strokeWidth = 1.0;
            _drawDottedLine(canvas, atom.position, bondedAtom.position, bondPaint, dotRadius: 1.5, spaceLength: 5);
            break;
          case 'Enlace Metálico':
            bondPaint
              ..color = Colors.white
              ..strokeWidth = 1.5;
            canvas.drawLine(atom.position, bondedAtom.position, bondPaint);
            break;
        }
      }
    }

    for (var atom in atoms) {
      final center = atom.position;
      final outerRadius = atom.element.atomicRadius / 10;
      final nucleusRadius = outerRadius * 1.4;
      final electronRadius = 2.0;
      final orbitPaint = Paint()
        ..color = Colors.grey.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;
      final protonPaint = Paint()
        ..color = Colors.redAccent[400]!;
      final neutronPaint = Paint()
        ..color = Colors.grey[300]!;
      final electronPaint = Paint()
        ..color = Colors.limeAccent;

      final numProtons = atom.element.atomicNumber;
      final numNeutrons = (atom.element.atomicWeight - numProtons).round();
      final totalParticles = numProtons + numNeutrons;
      final particleRadius = nucleusRadius / (sqrt(totalParticles) * 3.0);

      final positions = _getParticlePositions(totalParticles, nucleusRadius);

      for (int i = 0; i < numProtons; i++) {
        canvas.drawCircle(center + positions[i], particleRadius, protonPaint);
      }
      for (int i = 0; i < numNeutrons; i++) {
        canvas.drawCircle(center + positions[numProtons + i], particleRadius, neutronPaint);
      }

      final textSpan = TextSpan(
        text: atom.element.symbol,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));

      final uniqueRadii = atom.electronRadii.toSet().toList();
      for (var r in uniqueRadii) {
        canvas.drawCircle(center, r * orbitExpansionFactor, orbitPaint);
      }

      for (int i = 0; i < atom.electronRadii.length; i++) {
        final radius = atom.electronRadii[i] * orbitExpansionFactor;
        final angle = atom.electronAngles[i];
        final electronPosition = Offset(
          center.dx + radius * cos(angle),
          center.dy + radius * sin(angle),
        );
        final t = min(1.0, (radius / (100.0 * 1.5)));
        final electronColor = Color.lerp(Colors.limeAccent, Colors.red, t)!;
        final electronPaint = Paint()..color = electronColor;
        canvas.drawCircle(electronPosition, electronRadius, electronPaint);
      }

      if (atom.id == selectedAtom?.id) {
        final borderPaint = Paint()
          ..color = Colors.yellowAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0;
        canvas.drawCircle(center, outerRadius + 2, borderPaint);
      }
    }
  }

  List<Offset> _getParticlePositions(int count, double radius) {
    if (count == 0) return [];
    final positions = <Offset>[];
    double angle = 0;
    double spiralRadius = 0;
    final angleIncrement = 2 * pi / 1.618;
    final radiusIncrement = radius / sqrt(count);

    for (int i = 0; i < count; i++) {
      angle += angleIncrement;
      spiralRadius = radiusIncrement * sqrt(i + 1);
      final x = spiralRadius * cos(angle);
      final y = spiralRadius * sin(angle);
      positions.add(Offset(x, y));
    }
    return positions;
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, {double dashLength = 10, double spaceLength = 5}) {
    final distance = (p2 - p1).distance;
    final path = Path();
    double currentPosition = 0;
    while (currentPosition < distance) {
      path.moveTo(p1.dx + (p2.dx - p1.dx) * (currentPosition / distance), p1.dy + (p2.dy - p1.dy) * (currentPosition / distance));
      path.lineTo(p1.dx + (p2.dx - p1.dx) * (min(currentPosition + dashLength, distance) / distance), p1.dy + (p2.dy - p1.dy) * (min(currentPosition + dashLength, distance) / distance));
      currentPosition += dashLength + spaceLength;
    }
    canvas.drawPath(path, paint);
  }

  void _drawDottedLine(Canvas canvas, Offset p1, Offset p2, Paint paint, {double dotRadius = 2.0, double spaceLength = 5}) {
    final distance = (p2 - p1).distance;
    if (distance <= dotRadius * 2) return;
    final dotCount = (distance / (dotRadius * 2 + spaceLength)).floor();
    if (dotCount > 1) {
      for (int i = 0; i < dotCount; i++) {
        final t = i / (dotCount - 1).toDouble();
        final x = p1.dx + (p2.dx - p1.dx) * t;
        final y = p1.dy + (p2.dy - p1.dy) * t;
        canvas.drawCircle(Offset(x, y), dotRadius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is AtomPainter) {
      return oldDelegate.atoms.length != atoms.length || oldDelegate.selectedAtom?.id != selectedAtom?.id || oldDelegate.orbitExpansionFactor != orbitExpansionFactor;
    }
    return true;
  }
}