from pydantic import BaseModel, Field
from typing import List, Optional, Dict
from datetime import datetime

class ServiceStatus(BaseModel):
    name: str
    active: bool
    details: Optional[str] = None

class LoadStats(BaseModel):
    cpu: float = 0.0
    ram: float = 0.0
    net: float = 0.0

class HeartbeatPayload(BaseModel):
    ip: str
    hostname: Optional[str] = "Unknown"
    countryCode: Optional[str] = "UN"
    country: Optional[str] = "Unknown"
    region: Optional[str] = "Unknown"
    city: Optional[str] = "Unknown"
    services: List[ServiceStatus]
    load: Optional[LoadStats] = Field(default_factory=LoadStats)

class ServerConfigUpdate(BaseModel):
    gaming: Optional[bool] = None
    streaming: Optional[bool] = None
    paid: Optional[bool] = None
    enabled: Optional[bool] = None

class ServerResponse(HeartbeatPayload):
    server_id: str
    status: str  # active, down, maintenance
    last_heartbeat: datetime
    first_heartbeat: datetime
    gaming: bool = False
    streaming: bool = False
    paid: bool = True
    enabled: bool = True
