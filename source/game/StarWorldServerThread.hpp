#ifndef STAR_WORLD_SERVER_THREAD_HPP
#define STAR_WORLD_SERVER_THREAD_HPP

#include "StarWorldServer.hpp"
#include "StarThread.hpp"

namespace Star {

STAR_CLASS(WorldServerThread);

// Runs a WorldServer in a separate thread and guards exceptions that occur in
// it.  All methods are designed to not throw exceptions, but will instead log
// the error and trigger the WorldServerThread error state.
class WorldServerThread : public Thread {
public:
  typedef function<void(WorldServerThread*, WorldServer*)> WorldServerAction;

  WorldServerThread(WorldServerPtr server, WorldId worldId);
  ~WorldServerThread();

  WorldId worldId() const;

  void start();
  // Signals the WorldServerThread to stop and then joins it
  void stop();
  void setPause(shared_ptr<const atomic<bool>> pause);

  // An exception occurred from the actual WorldServer itself and the
  // WorldServerThread has stopped running.
  bool serverErrorOccurred();

  bool spawnTargetValid(SpawnTarget const& spawnTarget);

  bool addClient(ConnectionId clientId, SpawnTarget const& spawnTarget, bool isLocal);
  // Returns final outgoing packets
  List<PacketPtr> removeClient(ConnectionId clientId);

  List<ConnectionId> clients() const;
  bool hasClient(ConnectionId clientId) const;

  // Clients that have caused an error with incoming packets are removed from
  // the world and no further packets are handled from them.  They are still
  // added to this WorldServerThread, and must be removed and the final
  // outgoing packets should be sent to them.
  List<ConnectionId> erroredClients() const;

  void pushIncomingPackets(ConnectionId clientId, List<PacketPtr> packets);
  List<PacketPtr> pullOutgoingPackets(ConnectionId clientId);

  Maybe<Vec2F> playerRevivePosition(ConnectionId clientId) const;

  // Worlds use this to notify the universe server that their celestial type should change
  Maybe<pair<String, String>> pullNewPlanetType();

  // Executes the given action on the world in a thread safe context.  This
  // does *not* catch exceptions thrown by the action or set the server error
  // flag.
  void executeAction(WorldServerAction action);

  // If a callback is set here, then this is called after every world update,
  // also in a thread safe context.
  void setUpdateAction(WorldServerAction updateAction);

  // Syncs all active sectors to disk and reads the full content of the world
  // into memory, useful for the ship.
  WorldChunks readChunks();

protected:
  virtual void run();

private:
  void update(WorldServerFidelity fidelity);
  void sync();

  mutable RecursiveMutex m_mutex;

  HashSet<ConnectionId> m_clients;

  WorldServerPtr m_worldServer;
  WorldId m_worldId;
  WorldServerAction m_updateAction;

  mutable RecursiveMutex m_queueMutex;
  Map<ConnectionId, List<PacketPtr>> m_incomingPacketQueue;
  Map<ConnectionId, List<PacketPtr>> m_outgoingPacketQueue;

  atomic<bool> m_stop;
  shared_ptr<const atomic<bool>> m_pause;
  mutable atomic<bool> m_errorOccurred;
};

}

#endif
