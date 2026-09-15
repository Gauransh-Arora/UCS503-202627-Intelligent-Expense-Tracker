"""
Split Service — compute participant amounts for equal, percentage, and custom splits.
"""
from typing import Any

from app.models.split import SplitType
from app.schemas.split import ParticipantCreate


def compute_split_amounts(
    split_type: SplitType,
    total_amount: float,
    participants: list[ParticipantCreate],
) -> list[dict[str, Any]]:
    """
    Compute the final amount_owed for each participant.

    Args:
        split_type: EQUAL, PERCENTAGE, or CUSTOM
        total_amount: Total bill amount
        participants: Input participant list from the request

    Returns:
        List of dicts ready to insert into SplitParticipant rows.

    Raises:
        ValueError: If percentages don't sum to 100 or custom amounts don't sum to total.
    """
    result: list[dict[str, Any]] = []

    if split_type == SplitType.EQUAL:
        share = round(total_amount / len(participants), 2)
        # Adjust last participant for rounding differences
        remainder = round(total_amount - share * (len(participants) - 1), 2)

        for i, p in enumerate(participants):
            amount = remainder if i == len(participants) - 1 else share
            result.append({
                "participant_name": p.participant_name,
                "participant_user_id": p.participant_user_id,
                "amount_owed": amount,
                "percentage": round(100 / len(participants), 2),
                "is_payer": p.is_payer,
            })

    elif split_type == SplitType.PERCENTAGE:
        total_pct = sum(p.percentage or 0.0 for p in participants)
        if abs(total_pct - 100.0) > 0.01:
            raise ValueError(f"Percentages must sum to 100, got {total_pct:.2f}")

        for p in participants:
            pct = p.percentage or 0.0
            amount = round(total_amount * pct / 100, 2)
            result.append({
                "participant_name": p.participant_name,
                "participant_user_id": p.participant_user_id,
                "amount_owed": amount,
                "percentage": pct,
                "is_payer": p.is_payer,
            })

    elif split_type == SplitType.CUSTOM:
        total_custom = sum(p.amount_owed for p in participants)
        if abs(total_custom - total_amount) > 0.50:  # allow ₹0.50 rounding tolerance
            raise ValueError(
                f"Custom amounts sum to {total_custom:.2f} but total is {total_amount:.2f}"
            )

        for p in participants:
            result.append({
                "participant_name": p.participant_name,
                "participant_user_id": p.participant_user_id,
                "amount_owed": p.amount_owed,
                "percentage": round(p.amount_owed / total_amount * 100, 2),
                "is_payer": p.is_payer,
            })

    return result
