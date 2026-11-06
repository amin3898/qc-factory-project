from pydantic import BaseModel
from typing import List, Optional

class SpecItemBase(BaseModel):
    station_code: str
    item_key: str
    item_label: str
    data_type: str
    target_value: Optional[float] = None
    min_value: Optional[float] = None
    max_value: Optional[float] = None
    unit: Optional[str] = None

class SpecItemCreate(SpecItemBase):
    pass

class SpecItemOut(SpecItemBase):
    id: int
    model_id: int

    class Config:
        from_attributes = True

class ModelBase(BaseModel):
    code: str
    title: str
    description: Optional[str] = None

class ModelCreate(ModelBase):
    specifications: List[SpecItemCreate] = []

class ModelOut(ModelBase):
    id: int
    specifications: List[SpecItemOut] = []

    class Config:
        from_attributes = True

class InspectionDetailBase(BaseModel):
    item_key: str
    item_label: str
    measured_value: Optional[float] = None
    visual_status: Optional[str] = "OK"
    defect_type: Optional[str] = None

class InspectionDetailCreate(InspectionDetailBase):
    pass

class InspectionHeaderCreate(BaseModel):
    model_code: str
    station_code: str
    auditor_name: str
    shift: str
    inspection_date: Optional[str] = None
    details: List[InspectionDetailCreate]