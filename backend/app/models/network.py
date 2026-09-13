"""Graph payload contract used by the API and React Flow canvas."""

from typing import Any, Literal, TypedDict


class Position(TypedDict):
    x: float
    y: float


class GraphNode(TypedDict):
    id: str
    type: Literal["router", "interface", "prefix", "peer", "bundle", "service"]
    position: Position
    data: dict[str, Any]


class GraphEdge(TypedDict):
    id: str
    source: str
    target: str
    kind: str
    direction: str
    data: dict[str, Any]
