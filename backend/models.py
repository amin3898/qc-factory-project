from sqlalchemy import Column, Integer, String, Float, ForeignKey, DateTime, Enum, Text
from sqlalchemy.orm import relationship
import datetime
import enum
from database import Base

class DataType(str, enum.Enum):
    NUMERIC = "numeric"
    BOOLEAN = "boolean"
    TEXT = "text"

class ProductModel(Base):
    __tablename__ = "product_models"

    id = Column(Integer, primary_key=True, index=True)
    code = Column(String(50), unique=True, nullable=False, index=True)
    title = Column(String(100), nullable=False)
    description = Column(String(255), nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    specifications = relationship("ModelSpecification", back_populates="product_model", cascade="all, delete-orphan")
    inspections = relationship("Inspection", back_populates="product_model")


class ModelSpecification(Base):
    __tablename__ = "model_specifications"

    id = Column(Integer, primary_key=True, index=True)
    model_id = Column(Integer, ForeignKey("product_models.id", ondelete="CASCADE"), nullable=False)
    station_code = Column(String(50), nullable=False, index=True)
    item_key = Column(String(100), nullable=False)
    item_label = Column(String(150), nullable=False)

    data_type = Column(Enum(DataType), default=DataType.NUMERIC, nullable=False)
    
    target_value = Column(Float, nullable=True)
    min_value = Column(Float, nullable=True)
    max_value = Column(Float, nullable=True)
    unit = Column(String(20), nullable=True)
    expected_text = Column(String(100), nullable=True)

    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    product_model = relationship("ProductModel", back_populates="specifications")


class Inspection(Base):
    __tablename__ = "inspections"

    id = Column(Integer, primary_key=True, index=True)
    model_id = Column(Integer, ForeignKey("product_models.id"), nullable=False)
    station_code = Column(String(50), nullable=False)
    auditor_name = Column(String(100), nullable=False)
    shift = Column(String(20), default="AM")
    inspection_date = Column(String(20), nullable=True)
    overall_status = Column(String(10), nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    product_model = relationship("ProductModel", back_populates="inspections")
    details = relationship("InspectionDetail", back_populates="inspection", cascade="all, delete-orphan")
    nc_reports = relationship("NCReport", back_populates="inspection")


class InspectionDetail(Base):
    __tablename__ = "inspection_details"

    id = Column(Integer, primary_key=True, index=True)
    inspection_id = Column(Integer, ForeignKey("inspections.id", ondelete="CASCADE"), nullable=False)
    item_key = Column(String(100), nullable=False)
    item_label = Column(String(150), nullable=False)
    measured_value = Column(Float, nullable=True)
    visual_status = Column(String(10), nullable=True)
    defect_type = Column(String(100), nullable=True)
    status = Column(String(10), nullable=False)

    inspection = relationship("Inspection", back_populates="details")


class NCReport(Base):
    __tablename__ = "nc_reports"

    id = Column(Integer, primary_key=True, index=True)
    inspection_id = Column(Integer, ForeignKey("inspections.id"), nullable=False)
    station_code = Column(String(50), nullable=False)
    defect_description = Column(Text, nullable=False)
    severity = Column(String(20), default="Major")
    status = Column(String(20), default="Open")
    issued_at = Column(DateTime, default=datetime.datetime.utcnow)

    inspection = relationship("Inspection", back_populates="nc_reports")


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(20), default="auditor", nullable=False) # admin, engineer, auditor
    created_at = Column(DateTime, default=datetime.datetime.utcnow)